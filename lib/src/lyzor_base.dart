import 'dart:async';
import 'dart:io';
import 'package:lyzor/src/lyzor_request.dart';
import 'lyzor_exceptions.dart';
import 'package:lyzor/src/lyzor_response.dart';
import 'lyzor_result.dart';

part 'lyzor_context.dart';

typedef Handler = FutureOr<Object?> Function(Context ctx);
typedef Next = FutureOr<Object?> Function();
typedef Middleware = FutureOr<Object?> Function(Context ctx, Next next);
typedef Ctx = Context;

class _Route {
  final String method;
  final String path;
  final RegExp regex;
  final List<String> paramNames;
  final Handler handler;
  final List<Middleware> middlewares;

  _Route(this.method, this.path, this.regex, this.paramNames, this.handler, [this.middlewares = const []]);
}

class RouteDefinition {
  final Lyzor _api;
  final String _path;
  final List<Middleware> _middlewares = [];

  RouteDefinition(this._api, this._path);

  RouteDefinition use(Middleware middleware) {
    _middlewares.add(middleware);
    return this;
  }

  void get(Handler handler) => _api._addRoute('GET', _path, handler, _middlewares);
  void post(Handler handler) => _api._addRoute('POST', _path, handler, _middlewares);
  void put(Handler handler) => _api._addRoute('PUT', _path, handler, _middlewares);
  void patch(Handler handler) => _api._addRoute('PATCH', _path, handler, _middlewares);
  void delete(Handler handler) => _api._addRoute('DELETE', _path, handler, _middlewares);
  void head(Handler handler) => _api._addRoute('HEAD', _path, handler, _middlewares);
  void options(Handler handler) => _api._addRoute('OPTIONS', _path, handler, _middlewares);

  void all(Handler handler) {
    get(handler);
    post(handler);
    put(handler);
    patch(handler);
    delete(handler);
    head(handler);
    options(handler);
  }
}

abstract class Controller {
  void registerRoutes(Lyzor app);
}

class Lyzor {
  late HttpServer _server;
  final List<_Route> _routes = [];
  final List<Middleware> _globalMiddlewares = [];

  Lyzor();

  Lyzor use(Middleware middleware) {
    _globalMiddlewares.add(middleware);

    return this;
  }

  Lyzor addController(Controller controller) {
    controller.registerRoutes(this);

    return this;
  }

  RouteDefinition route(String path) {
    return RouteDefinition(this, path);
  }

  void _addRoute(String method, String path, Handler handler, List<Middleware> routeMiddlewares) {
    final paramNames = <String>[];
    final pattern = path.replaceAllMapped(RegExp(r':(\w+)'), (m) {
      paramNames.add(m[1]!);
      return '([^/]+)';
    });
    final regex = RegExp('^$pattern\$');
    _routes.add(_Route(method, path, regex, paramNames, handler, routeMiddlewares));
  }

  Future<void> _handleError(HttpRequest rawReq, Object error, StackTrace st, String method, String path) async {
    final response = Response(rawReq.response);

    if (error is MethodNotAllowedException) {
      response.setHeader('Allow', error.allowedMethods.join(', '));
      await response.status(error.statusCode).json({'error': error.message, 'allowed': error.allowedMethods.toList()});
      return;
    }

    if (error is HttpException) {
      print('[$method $path] HTTP Error: ${error.statusCode} - ${error.message}');
      await response.status(error.statusCode).json({'error': error.message, 'details': error.details});
    } else {
      print('[$method $path] Unhandled Error: $error\n$st');
      await response.status(HttpStatus.internalServerError).json({'error': 'Internal Server Error'});
    }
  }

  Result? _coerce(Object? v) {
    if (v == null) return null;
    if (v is Result) return v;
    if (v is String) return Results.text(v);
    if (v is Map || v is List || v is num || v is bool) return Results.json(v);
    return Results.text(v.toString());
  }

  Future<void> run({String host = '127.0.0.1', int port = 8080, SecurityContext? securityContext}) async {
    try {
      if (securityContext != null) {
        print('SecurityContext is not null');
        print('Server will run on port 443');
        _server = await HttpServer.bindSecure(host, 443, securityContext);
        print('Server running at http://$host:443/');
      } else {
        _server = await HttpServer.bind(host, port);
        print('Server running at http://$host:$port/');
      }

      await for (final rawReq in _server) {
        final requestMethod = rawReq.method;
        final requestPath = rawReq.uri.path;

        try {
          final method = requestMethod;
          final path = requestPath;

          _Route? matchedRoute;
          Map<String, String> pathParams = {};
          final allowedMethods = <String>{};

          for (final route in _routes) {
            final match = route.regex.firstMatch(path);
            if (match == null) continue;

            allowedMethods.add(route.method);

            if (route.method == method) {
              matchedRoute = route;

              for (var i = 0; i < route.paramNames.length; i++) {
                pathParams[route.paramNames[i]] = match.group(i + 1)!;
              }
              break;
            }
          }

          if (matchedRoute == null) {
            if (allowedMethods.isNotEmpty) {
              throw MethodNotAllowedException(method, path, allowedMethods);
            }
            throw NotFoundException('Route $method $path not found');
          }

          final request = Request(rawReq, pathParams);
          final response = Response(rawReq.response);
          final context = Context(request, response);

          final currentRoute = matchedRoute;

          List<Middleware> pipeline = [
            ..._globalMiddlewares,
            ...currentRoute.middlewares,
            (ctx, next) => currentRoute.handler(ctx),
          ];

          int middlewareIndex = 0;

          FutureOr<Object?> next() async {
            if (middlewareIndex >= pipeline.length) return null;
            final current = pipeline[middlewareIndex++];
            return await current(context, next);
          }

          final out = await next();
          final result = _coerce(out);

          if (result != null && !context.response.isCommitted) {
            await result.execute(context.response);
          }
        } catch (e, st) {
          await _handleError(rawReq, e, st, requestMethod, requestPath);
        }
      }
    } catch (e, st) {
      print('Server startup error: $e\n$st');
    }
  }
}
