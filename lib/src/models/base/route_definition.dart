import 'package:lyzor/src/lyzor_base.dart';
import 'package:lyzor/src/lyzor_middleware.dart';
import 'package:lyzor/src/lyzor_router.dart';
import 'package:lyzor/src/models/router/route.dart';

class RouteDefinition {
  final Router router;
  final String _path;
  final List<Middleware> _middlewares = [];

  RouteDefinition(this.router, this._path);

  RouteDefinition use(Middleware middleware) {
    _middlewares.add(middleware);
    return this;
  }

  Route get(Handler handler) => router.addRoute('GET', _path, handler, _middlewares);
  Route post(Handler handler) => router.addRoute('POST', _path, handler, _middlewares);
  Route put(Handler handler) => router.addRoute('PUT', _path, handler, _middlewares);
  Route patch(Handler handler) => router.addRoute('PATCH', _path, handler, _middlewares);
  Route delete(Handler handler) => router.addRoute('DELETE', _path, handler, _middlewares);
  Route head(Handler handler) => router.addRoute('HEAD', _path, handler, _middlewares);
  Route options(Handler handler) => router.addRoute('OPTIONS', _path, handler, _middlewares);

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
