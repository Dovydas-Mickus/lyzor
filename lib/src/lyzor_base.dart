import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../lyzor.dart';
import 'lyzor_registry.dart';
import 'lyzor_request.dart';
import 'lyzor_router.dart';
import 'models/base/route_definition.dart';
import 'models/base/route_group.dart';
import 'utils/base/base_helper.dart';

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
  Duration? requestTimeout;
  bool poweredBy = true;

  int _activeRequests = 0;
  Completer<void>? _drainCompleter;

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

  /// Stops accepting new connections and waits for in-flight requests to finish.
  Future<void> close() async {
    await _server.close();
    if (_activeRequests > 0) {
      _drainCompleter = Completer<void>();
      await _drainCompleter!.future;
    }
  }

  Future<void> _handleRequest(HttpRequest rawReq) async {
    _activeRequests++;
    final requestMethod = rawReq.method;
    final requestPath = rawReq.uri.path;

    final response = Response(rawReq.response, poweredBy: poweredBy);
    final request = Request(rawReq, pathParams: {}, maxBodySize: maxBodySize);
    final context = Context(request, _registry);

    try {
      await runZoned(() async {
        try {
          final timeout = requestTimeout;
          Future<Object?> dispatchFuture = _dispatch(context);
          if (timeout != null) {
            dispatchFuture = dispatchFuture.timeout(
              timeout,
              onTimeout: () => throw RequestTimeoutException(),
            );
          }
          final finalOutput = await dispatchFuture;
          final result = BaseHelper.coerce(finalOutput);

          if (result != null && !response.isCommitted) {
            await result.execute(response);
          }
        } catch (e, st) {
          if (!response.isCommitted) {
            await BaseHelper.handleError(response, e, st, requestMethod, requestPath);
          }
        }
      }, zoneValues: {#lyzor_context: context});
    } finally {
      _activeRequests--;
      if (_activeRequests == 0 && _drainCompleter != null && !_drainCompleter!.isCompleted) {
        _drainCompleter!.complete();
      }
    }
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

  static Future<void> spawn(
    AppBuilder builder, {
    int count = 0,
    String host = '127.0.0.1',
    int port = 8080,
  }) async {
    final workers = count <= 0 ? Platform.numberOfProcessors : count;

    print('Starting $workers workers on http://$host:$port');

    // Main port collects two message types from workers:
    //   SendPort  — the worker's own port, sent once on startup
    //   'done'    — sent after the worker has drained and closed
    final mainPort = ReceivePort();
    final workerSendPorts = <SendPort>[];
    var drained = 0;
    final allPortsReady = Completer<void>();
    final allDrained = Completer<void>();

    mainPort.listen((msg) {
      if (msg is SendPort) {
        workerSendPorts.add(msg);
        if (workerSendPorts.length == workers) allPortsReady.complete();
      } else if (msg == 'done') {
        drained++;
        if (drained >= workers && !allDrained.isCompleted) allDrained.complete();
      }
    });

    final isolates = await Future.wait([
      for (int i = 0; i < workers; i++)
        Isolate.spawn(_startWorker, {
          'builder': builder,
          'host': host,
          'port': port,
          'mainPort': mainPort.sendPort,
        }),
    ]);

    // Wait until every worker has registered its SendPort before we arm the
    // signal handlers — ensures no shutdown message is lost.
    await allPortsReady.future;

    final signals = <Future<ProcessSignal>>[ProcessSignal.sigint.watch().first];
    if (!Platform.isWindows) {
      signals.add(ProcessSignal.sigterm.watch().first);
    }
    await Future.any(signals);

    print('\nShutting down...');
    for (final workerPort in workerSendPorts) {
      workerPort.send('shutdown');
    }

    try {
      await allDrained.future.timeout(const Duration(seconds: 30));
      print('All workers shut down gracefully.');
    } on TimeoutException {
      print('Shutdown timeout — force-killing remaining workers.');
      for (final isolate in isolates) {
        isolate.kill(priority: Isolate.beforeNextEvent);
      }
    }

    mainPort.close();
  }

  static Future<void> _startWorker(Map<String, dynamic> message) async {
    final AppBuilder builder = message['builder'];
    final String host = message['host'];
    final int port = message['port'];
    final SendPort mainPort = message['mainPort'];

    final app = builder();

    // Register this worker's port with the main isolate so it can receive the
    // shutdown signal, then listen for it.
    final workerPort = ReceivePort();
    mainPort.send(workerPort.sendPort);

    workerPort.listen((_) async {
      await app.close();   // stops accepting requests, drains in-flight ones
      mainPort.send('done');
      workerPort.close();
    });

    await app.run(host: host, port: port, shared: true);
    // app.run() returns once _server.close() is called by the listener above.
    // The isolate stays alive until workerPort.close() is called, giving
    // app.close() time to finish draining before the isolate exits.
  }
}
