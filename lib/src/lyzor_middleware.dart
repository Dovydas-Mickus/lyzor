import 'dart:async';
import 'dart:convert' show base64Url;
import 'dart:io' show Cookie, SameSite;
import 'dart:math' show Random;

import '../lyzor.dart';
import 'lyzor_base.dart';

typedef Middleware = FutureOr<Object?> Function(Context ctx, Next next);

Middleware recovery({
  FutureOr<Object?> Function(Context ctx, NotFoundException e)? onNotFound,
  FutureOr<Object?> Function(Context ctx, MethodNotAllowedException e)? onMethodNotAllowed,
}) {
  return (ctx, next) async {
    try {
      return await next();
    } catch (e, st) {
      if (e is NotFoundException && onNotFound != null) {
        return await onNotFound(ctx, e);
      }

      if (e is MethodNotAllowedException && onMethodNotAllowed != null) {
        return await onMethodNotAllowed(ctx, e);
      }

      if (e is HttpException) {
        print('[HTTP ${e.statusCode}] ${ctx.method} ${ctx.uri.path} - ${e.message}');

        return JsonResult({'error': e.message, if (e.details != null) 'details': e.details}, status: e.statusCode);
      }

      print('[Recovery] Unhandled Error: $e\n$st');

      return JsonResult({'error': 'Internal Server Error'}, status: 500);
    }
  };
}

/// [logQuery] controls whether query parameters are included in log output.
/// Defaults to false to avoid logging tokens passed as query params.
Middleware logger({bool logQuery = false}) {
  return (ctx, next) async {
    final sw = Stopwatch()..start();
    final out = await next();
    sw.stop();

    int status = (out is Result) ? out.status : 200;
    final path = logQuery ? ctx.uri.toString() : ctx.uri.path;
    print('${ctx.method} $path | $status | ${sw.elapsedMilliseconds}ms');

    return out;
  };
}

Middleware validateBody(Validator validator) {
  return (ctx, next) async {
    try {
      final body = await ctx.json;

      final errors = validator.validate(body);

      if (errors.isNotEmpty) {
        return JsonResult({'error': 'Validation Failed', 'details': errors}, status: 400);
      }

      return await next();
    } on HttpException catch (_) {
      rethrow;
    } catch (e) {
      return JsonResult({'error': 'Invalid JSON body'}, status: 400);
    }
  };
}

Middleware validateQuery(Validator validator) {
  return (ctx, next) async {
    final errors = validator.validate(ctx.queryParams);
    if (errors.isNotEmpty) {
      return JsonResult({'error': 'Invalid query parameters', 'details': errors}, status: 400);
    }
    return await next();
  };
}

Middleware validateFormData(Validator validator) {
  return (ctx, next) async {
    try {
      final data = await ctx.formData;
      final errors = validator.validate(data);
      if (errors.isNotEmpty) {
        return JsonResult({'error': 'Validation Failed', 'details': errors}, status: 400);
      }
      return await next();
    } on HttpException catch (_) {
      rethrow;
    } catch (e) {
      return JsonResult({'error': 'Invalid form data'}, status: 400);
    }
  };
}

Middleware securityHeaders({
  String? contentSecurityPolicy = "default-src 'self'",
  String xFrameOptions = 'SAMEORIGIN',
  String referrerPolicy = 'strict-origin-when-cross-origin',
  String? strictTransportSecurity = 'max-age=31536000; includeSubDomains',
}) {
  return (ctx, next) async {
    final result = await next();
    if (result is Result) {
      var r = result;
      if (contentSecurityPolicy != null) r = r.withHeader('Content-Security-Policy', contentSecurityPolicy);
      r = r.withHeader('X-Frame-Options', xFrameOptions);
      r = r.withHeader('X-Content-Type-Options', 'nosniff');
      r = r.withHeader('Referrer-Policy', referrerPolicy);
      if (strictTransportSecurity != null) r = r.withHeader('Strict-Transport-Security', strictTransportSecurity);
      return r;
    }
    return result;
  };
}

class _RateLimitBucket {
  DateTime windowStart;
  int count;
  _RateLimitBucket(this.windowStart) : count = 1;
}

/// Fixed-window rate limiter. Counts are per isolate — not shared across
/// workers when using [Lyzor.spawn].
///
/// [RateLimiter] is usable directly as a [Middleware] via its [call] method.
/// Call [RateLimiter.cancel] during shutdown to stop the background cleanup timer.
///
/// ```dart
/// final limiter = rateLimit(maxRequests: 100, window: Duration(minutes: 1));
/// app.use(limiter);
///
/// // on shutdown:
/// limiter.cancel();
/// await app.close();
/// ```
class RateLimiter {
  final int _maxRequests;
  final Duration _window;
  final String Function(Context ctx)? _keyBy;
  final Map<String, _RateLimitBucket> _buckets = {};
  late final Timer _timer;

  RateLimiter._({
    required int maxRequests,
    required Duration window,
    String Function(Context ctx)? keyBy,
  })  : _maxRequests = maxRequests,
        _window = window,
        _keyBy = keyBy {
    _timer = Timer.periodic(window, (_) => _prune());
  }

  void _prune() {
    final now = DateTime.now();
    _buckets.removeWhere((_, bucket) => now.difference(bucket.windowStart) >= _window);
  }

  /// Stops the background cleanup timer. Call this when the server shuts down.
  void cancel() => _timer.cancel();

  FutureOr<Object?> call(Context ctx, Next next) async {
    final key = _keyBy != null ? _keyBy!(ctx) : ctx.request.ip;
    final now = DateTime.now();
    final bucket = _buckets[key];

    if (bucket == null || now.difference(bucket.windowStart) >= _window) {
      _buckets[key] = _RateLimitBucket(now);
    } else {
      bucket.count++;
      if (bucket.count > _maxRequests) {
        return JsonResult({'error': 'Too Many Requests'}, status: 429)
            .withHeader('Retry-After', _window.inSeconds.toString());
      }
    }

    return await next();
  }
}

RateLimiter rateLimit({
  required int maxRequests,
  required Duration window,
  String Function(Context ctx)? keyBy,
}) {
  return RateLimiter._(maxRequests: maxRequests, window: window, keyBy: keyBy);
}

String _generateCsrfToken() {
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  return base64Url.encode(bytes);
}

/// Double-submit cookie CSRF protection.
///
/// On safe requests (GET, HEAD, OPTIONS) a token is issued via cookie if one
/// does not already exist. On mutating requests the cookie value must be
/// echoed in the [headerName] request header, otherwise a 403 is returned.
///
/// The cookie is intentionally NOT HttpOnly so that client-side JS can read
/// and forward it. Set [cookieSecure] to true in production (HTTPS).
Middleware csrf({
  String cookieName = 'csrf_token',
  String headerName = 'x-csrf-token',
  Set<String> safeMethods = const {'GET', 'HEAD', 'OPTIONS'},
  String cookiePath = '/',
  bool cookieSecure = false,
}) {
  return (ctx, next) async {
    final existingToken = ctx.request.cookies[cookieName];

    if (!safeMethods.contains(ctx.method)) {
      final headerToken = ctx.headers.value(headerName);
      if (existingToken == null || headerToken == null || headerToken != existingToken) {
        return JsonResult({'error': 'CSRF token invalid'}, status: 403);
      }
    }

    final result = await next();

    if (existingToken == null) {
      final cookie = Cookie(cookieName, _generateCsrfToken())
        ..path = cookiePath
        ..secure = cookieSecure
        ..httpOnly = false
        ..sameSite = SameSite.lax;
      if (result is Result) return result.withCookie(cookie);
    }

    return result;
  };
}

Middleware cors({
  String origin = '*',
  String methods = 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  String headers = 'Origin, X-Requested-With, Content-Type, Accept, Authorization',
}) {
  return (ctx, next) async {
    if (ctx.method == 'OPTIONS') {
      return TextResult('', status: 204)
          .withHeader('Access-Control-Allow-Origin', origin)
          .withHeader('Access-Control-Allow-Methods', methods)
          .withHeader('Access-Control-Allow-Headers', headers);
    }

    final result = await next();

    if (result is Result) {
      return result
          .withHeader('Access-Control-Allow-Origin', origin)
          .withHeader('Access-Control-Allow-Methods', methods)
          .withHeader('Access-Control-Allow-Headers', headers);
    }

    return result;
  };
}
