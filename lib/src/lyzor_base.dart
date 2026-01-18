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

  Route get(Handler handler) => _api._addRoute('GET', _path, handler, _middlewares);
  Route post(Handler handler) => _api._addRoute('POST', _path, handler, _middlewares);
  Route put(Handler handler) => _api._addRoute('PUT', _path, handler, _middlewares);
  Route patch(Handler handler) => _api._addRoute('PATCH', _path, handler, _middlewares);
  Route delete(Handler handler) => _api._addRoute('DELETE', _path, handler, _middlewares);
  Route head(Handler handler) => _api._addRoute('HEAD', _path, handler, _middlewares);
  Route options(Handler handler) => _api._addRoute('OPTIONS', _path, handler, _middlewares);

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

  Route _addRoute(String method, String path, Handler handler, List<Middleware> routeMiddlewares) {
    return _router.addRoute(method, path, handler, routeMiddlewares);
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

  Future<void> run({String host = '127.0.0.1', int port = 8080}) async {
    try {
      _server = await HttpServer.bind(host, port);
      print('Server running at http://$host:$port/');

      await for (final rawReq in _server) {
        _handleRequest(rawReq);
      }
    } catch (e, st) {
      print('Server startup error: $e\n$st');
    }
  }

  Future<void> _handleRequest(HttpRequest rawReq) async {
    final requestMethod = rawReq.method;
    final requestPath = rawReq.uri.path;
    Map<String, String> pathParams;

    try {
      pathParams = rawReq.uri.queryParameters;
    } catch (e) {
      print(e);
      pathParams = {};
    }

    final response = Response(rawReq.response);
    final request = Request(rawReq, pathParams: pathParams, maxBodySize: maxBodySize);
    final context = Context(request, response, _registry);

    try {
      final finalOutput = await _dispatch(context);
      final result = _coerce(finalOutput);

      if (result != null && !context.response.isCommitted) {
        await result.execute(context.response);
      }
    } catch (e, st) {
      if (!context.response.isCommitted) {
        await _handleError(rawReq, e, st, requestMethod, requestPath);
      }
    }
  }

  Future<Object?> _dispatch(Context ctx, [int index = 0]) async {
    if (index < _globalMiddlewares.length) {
      return _coerce(await _globalMiddlewares[index](ctx, () => _dispatch(ctx, index + 1)));
    }

    final match = _router.lookup(ctx.method, ctx.uri.path);

    if (match == null) {
      throw NotFoundException('Route ${ctx.method} ${ctx.uri.path} not found');
    }

    if (match.isMethodNotAllowed) {
      throw MethodNotAllowedException(ctx.method, ctx.uri.path, match.allowedMethods);
    }

    final route = match.data!;
    ctx.request.pathParams = match.params;

    final routePipeline = [...route.middlewares, (c, _) => route.handler(c)];
    return await _executePipeline(ctx, routePipeline);
  }

  Future<Object?> _executePipeline(Context ctx, List<Middleware> pipeline, [int index = 0]) async {
    if (index >= pipeline.length) return null;

    return _coerce(await pipeline[index](ctx, () => _executePipeline(ctx, pipeline, index + 1)));
  }
}
