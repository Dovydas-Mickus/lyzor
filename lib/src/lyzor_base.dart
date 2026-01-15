import 'dart:async';
import 'dart:io';
import 'package:lyzor/src/lyzor_registry.dart';
import 'package:lyzor/src/lyzor_request.dart';
import 'package:lyzor/src/lyzor_router.dart';
import 'lyzor_exceptions.dart';
import 'package:lyzor/src/lyzor_response.dart';
import 'lyzor_result.dart';

part 'lyzor_context.dart';

typedef Handler = FutureOr<Object?> Function(Context ctx);
typedef Next = FutureOr<Object?> Function();
typedef Middleware = FutureOr<Object?> Function(Context ctx, Next next);
typedef Ctx = Context;

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
  final Router _router = Router();
  final List<Middleware> _globalMiddlewares = [];
  final Registry _registry = Registry();
  int maxBodySize = 10 * 1024 * 1024;

  Lyzor();

  Lyzor provide<T>(T service) {
    _registry.register<T>(service);

    return this;
  }

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
    _router.addRoute(method, path, handler, routeMiddlewares);
  }

  Future<void> _handleError(HttpRequest rawReq, Object error, StackTrace st, String method, String path) async {
    final response = Response(rawReq.response);
    Result result;

    if (error is MethodNotAllowedException) {
      result = Results.json(
        {'error': error.message, 'allowed': error.allowedMethods.toList()},
        status: HttpStatus.methodNotAllowed,
        headers: {'Allow': error.allowedMethods.join(', ')},
      );
    } else if (error is NotFoundException) {
      result = Results.json({'error': error.message}, status: HttpStatus.notFound);
    } else if (error is HttpException) {
      result = Results.json({'error': error.message, 'details': error.details}, status: error.statusCode);
    } else {
      print('[$method $path] Unhandled Error: $error\n$st');
      result = Results.json({'error': 'Internal Server Error'}, status: 500);
    }

    await result.execute(response);
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
          final match = _router.lookup(requestMethod, requestPath);

          if (match == null) {
            throw NotFoundException('Route $requestMethod $requestPath not found');
          }

          if (match.isMethodNotAllowed) {
            throw MethodNotAllowedException(requestMethod, requestPath, match.allowedMethods);
          }

          final route = match.data!;
          final request = Request(rawReq, pathParams: match.params, maxBodySize: maxBodySize);
          final response = Response(rawReq.response);
          final context = Context(request, response, _registry);

          List<Middleware> pipeline = [..._globalMiddlewares, ...route.middlewares, (ctx, next) => route.handler(ctx)];

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
