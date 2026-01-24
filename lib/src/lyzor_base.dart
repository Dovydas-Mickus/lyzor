import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:lyzor/src/lyzor_middleware.dart';
import 'package:lyzor/src/lyzor_registry.dart';
import 'package:lyzor/src/lyzor_request.dart';
import 'package:lyzor/src/lyzor_router.dart';
import 'package:lyzor/src/models/base/route_definition.dart';
import 'package:lyzor/src/utils/base/base_helper.dart';
import 'lyzor_exceptions.dart';
import 'package:lyzor/src/lyzor_response.dart';
import 'models/base/route_group.dart';

part 'lyzor_context.dart';

typedef Handler = FutureOr<Object?> Function();
typedef Next = FutureOr<Object?> Function();
typedef Ctx = Context;
typedef AppBuilder = Lyzor Function();

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

  RouteGroup group(String prefix) {
    return RouteGroup(_router, prefix);
  }

  RouteDefinition route(String path) {
    return RouteDefinition(_router, path);
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
        final result = BaseHelper.coerce(finalOutput);

        if (result != null && !response.isCommitted) {
          await result.execute(response);
        }
      } catch (e, st) {
        if (!response.isCommitted) {
          await BaseHelper.handleError(rawReq, e, st, requestMethod, requestPath);
        }
      }
    }, zoneValues: {#lyzor_context: context});
  }

  Future<Object?> _dispatch(Context ctx, [int index = 0]) async {
    if (index < _globalMiddlewares.length) {
      return BaseHelper.coerce(await _globalMiddlewares[index](ctx, () => _dispatch(ctx, index + 1)));
    }

    final match = _router.lookup(ctx.method, ctx.uri.path);

    if (match == null) {
      throw NotFoundException('Route ${ctx.method} ${ctx.uri.path} not found');
    }

    if (match.isMethodNotAllowed) {
      throw MethodNotAllowedException(ctx.method, ctx.uri.path, allowedMethods: match.allowedMethods);
    }

    final route = match.data!;
    ctx.request.pathParams = match.params;

    final routePipeline = [...route.middlewares, (c, _) => route.handler()];
    return await BaseHelper.executePipeline(ctx, routePipeline);
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
