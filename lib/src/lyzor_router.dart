import 'package:lyzor/src/lyzor_middleware.dart';
import 'package:lyzor/src/models/router/node.dart';
import 'package:lyzor/src/models/router/route.dart';
import 'package:lyzor/src/models/router/search_result.dart';
import 'package:lyzor/src/utils/router/router_helper.dart';

import 'lyzor_base.dart';

class Router {
  final Node _root = Node();

  Route _addRoute(String method, String path, Handler handler, List<Middleware> middlewares) {
    Node current = _root;
    final segments = RouterHelper.splitPath(path);

    for (final segment in segments) {
      if (segment.startsWith(':')) {
        current.paramChild ??= Node();
        current.paramName = segment.substring(1);
        current = current.paramChild!;
      } else if (segment == '*') {
        current.wildcardChild ??= Node();
        current = current.wildcardChild!;
      } else {
        current = current.staticChildren.putIfAbsent(segment, () => Node());
      }
    }

    final route = Route(method, handler, middlewares);

    current.routes[method] = route;

    return route;
  }

  SearchResult? lookup(String method, String path) => RouterHelper.lookup(method, path, _root);

  Route addRoute(String method, String path, Handler handler, List<Middleware> routeMiddlewares) {
    return _addRoute(method, path, handler, routeMiddlewares);
  }
}
