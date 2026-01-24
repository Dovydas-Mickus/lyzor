import 'package:lyzor/src/lyzor_middleware.dart';
import 'package:lyzor/src/lyzor_router.dart';
import 'package:lyzor/src/models/base/route_definition.dart';

class RouteGroup {
  final Router _router;
  final String _prefix;
  final List<Middleware> _groupMiddlewares = [];

  RouteGroup(this._router, this._prefix);

  RouteGroup use(Middleware middleware) {
    _groupMiddlewares.add(middleware);
    return this;
  }

  RouteDefinition route(String path) {
    final fullPath = '$_prefix/$path'.replaceAll('//', '/');

    final def = RouteDefinition(_router, fullPath);

    for (var m in _groupMiddlewares) {
      def.use(m);
    }

    return def;
  }
}
