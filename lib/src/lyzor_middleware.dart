import 'package:lyzor/lyzor.dart';

Middleware recovery() {
  return (ctx, next) async {
    try {
      return await next();
    } catch (e, st) {
      if (e is HttpException) {
        print('[HTTP ${e.statusCode}] ${ctx.method} ${ctx.uri.path} - ${e.message}');

        return JsonResult({'error': e.message, if (e.details != null) 'details': e.details}, status: e.statusCode);
      }

      print('[Recovery] Unhandled Error: $e\n$st');

      return JsonResult({'error': 'Internal Server Error'}, status: 500);
    }
  };
}

Middleware logger() {
  return (ctx, next) async {
    final sw = Stopwatch()..start();
    final out = await next();
    sw.stop();

    int status = (out is Result) ? out.status : 200;
    print('${ctx.method} ${ctx.uri.path} | $status | ${sw.elapsedMilliseconds}ms');

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
