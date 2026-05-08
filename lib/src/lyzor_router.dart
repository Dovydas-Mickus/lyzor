import '../lyzor.dart';
import 'lyzor_base.dart';
import 'models/router/node.dart';
import 'models/router/route.dart';
import 'models/router/search_result.dart';
import 'utils/router/router_helper.dart';

class Router {
  final Node _root = Node();

  SearchResult? lookup(String method, String path) => RouterHelper.lookup(method, path, _root);

  Route addRoute(String method, String path, Handler handler, List<Middleware> routeMiddlewares) {
    Node current = _root;
    final segments = RouterHelper.splitPath(path);

    for (final segment in segments) {
      if (segment.startsWith(':')) {
        final name = segment.substring(1);
        if (current.paramName != null && current.paramName != name) {
          throw ArgumentError(
            'Conflicting parameter names: ":${current.paramName}" vs ":$name" at the same path position. '
            'Routes sharing a parameter slot must use the same name.',
          );
        }
        current.paramChild ??= Node();
        current.paramName = name;
        current = current.paramChild!;
      } else if (segment == '*') {
        current.wildcardChild ??= Node();
        current = current.wildcardChild!;
      } else {
        current = current.staticChildren.putIfAbsent(segment, () => Node());
      }
    }

    final route = Route(method, handler, routeMiddlewares);
    current.routes[method] = route;
    return route;
  }
}
