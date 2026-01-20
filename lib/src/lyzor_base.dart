import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:lyzor/src/lyzor_registry.dart';
import 'package:lyzor/src/lyzor_request.dart';
import 'package:lyzor/src/lyzor_router.dart';
import 'lyzor_exceptions.dart';
import 'package:lyzor/src/lyzor_response.dart';
import 'lyzor_result.dart';

part 'lyzor_context.dart';

typedef Handler = FutureOr<Object?> Function();
typedef Next = FutureOr<Object?> Function();
typedef Middleware = FutureOr<Object?> Function(Context ctx, Next next);
typedef Ctx = Context;
typedef AppBuilder = Lyzor Function();

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

class RouteGroup {
  final Lyzor _api;
  final String _prefix;
  final List<Middleware> _groupMiddlewares = [];

  RouteGroup(this._api, this._prefix);

  RouteGroup use(Middleware middleware) {
    _groupMiddlewares.add(middleware);
    return this;
  }

  RouteDefinition route(String path) {
    final fullPath = '$_prefix/$path'.replaceAll('//', '/');

    final def = RouteDefinition(_api, fullPath);

    for (var m in _groupMiddlewares) {
      def.use(m);
    }

    return def;
  }
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
      result = JsonResult(
        {'error': error.message, 'allowed': error.allowedMethods.toList()},
        status: HttpStatus.methodNotAllowed,
        headers: {'Allow': error.allowedMethods.join(', ')},
      );
    } else if (error is NotFoundException) {
      result = JsonResult({'error': error.message}, status: HttpStatus.notFound);
    } else if (error is HttpException) {
      result = JsonResult({'error': error.message, 'details': error.details}, status: error.statusCode);
    } else {
      print('[$method $path] Unhandled Error: $error\n$st');
      result = JsonResult({'error': 'Internal Server Error'}, status: 500);
    }

    await result.execute(response);
  }

  Result? _coerce(Object? v) {
    if (v == null) return null;
    if (v is Result) return v;

    if (v is Map || v is List) return JsonResult(v);
    if (v is String) return TextResult(v);

    return TextResult(v.toString());
  }

  Future<void> run({String host = '127.0.0.1', int port = 8080, bool shared = false}) async {
    try {
      _server = await HttpServer.bind(host, port, shared: shared);
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

    final response = Response(rawReq.response);
    final request = Request(rawReq, pathParams: {}, maxBodySize: maxBodySize);
    final context = Context(request, _registry);

    runZoned(() async {
      try {
        final finalOutput = await _dispatch(context);
        final result = _coerce(finalOutput);

        if (result != null && !response.isCommitted) {
          await result.execute(response);
        }
      } catch (e, st) {
        if (!response.isCommitted) {
          await _handleError(rawReq, e, st, requestMethod, requestPath);
        }
      }
    }, zoneValues: {#lyzor_context: context});
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

    final routePipeline = [...route.middlewares, (c, _) => route.handler()];
    return await _executePipeline(ctx, routePipeline);
  }

  Future<Object?> _executePipeline(Context ctx, List<Middleware> pipeline, [int index = 0]) async {
    if (index >= pipeline.length) return null;

    return _coerce(await pipeline[index](ctx, () => _executePipeline(ctx, pipeline, index + 1)));
  }

  static Future<void> spawn(AppBuilder builder, {int count = 0, String host = '127.0.0.1', int port = 8080}) async {
    final workers = count <= 0 ? Platform.numberOfProcessors : count;

    print('Starting $workers workers on http://$host:$port');

    for (int i = 0; i < workers; i++) {
      Isolate.spawn(_startWorker, {'builder': builder, 'host': host, 'port': port});
    }

    await ProcessSignal.sigint.watch().first;
  }

  static void _startWorker(Map<String, dynamic> message) async {
    final AppBuilder builder = message['builder'];
    final String host = message['host'];
    final int port = message['port'];

    final app = builder();

    await app.run(host: host, port: port, shared: true);
  }
}

extension LyzorGroups on Lyzor {
  RouteGroup group(String prefix) {
    return RouteGroup(this, prefix);
  }
}
