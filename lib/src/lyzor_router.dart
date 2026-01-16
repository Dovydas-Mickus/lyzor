import 'lyzor_base.dart';

class Route {
  final Handler handler;
  final List<Middleware> middlewares;
  final String method;

  Route use(Middleware middleware) {
    middlewares.add(middleware);
    return this;
  }

  Route(this.method, this.handler, this.middlewares);
}

class _Node {
  final Map<String, _Node> staticChildren = {};

  _Node? paramChild;
  String? paramName;

  _Node? wildcardChild;

  final Map<String, Route> routes = {};

  bool get isLeaf => routes.isNotEmpty;
}

class Router {
  final _Node _root = _Node();

  Route addRoute(String method, String path, Handler handler, List<Middleware> middlewares) {
    _Node current = _root;
    final segments = _splitPath(path);

    for (final segment in segments) {
      if (segment.startsWith(':')) {
        current.paramChild ??= _Node();
        current.paramName = segment.substring(1);
        current = current.paramChild!;
      } else if (segment == '*') {
        current.wildcardChild ??= _Node();
        current = current.wildcardChild!;
      } else {
        current = current.staticChildren.putIfAbsent(segment, () => _Node());
      }
    }

    final route = Route(method, handler, middlewares);

    current.routes[method] = route;

    return route;
  }

  _SearchResult? lookup(String method, String path) {
    _Node current = _root;
    final segments = _splitPath(path);
    final Map<String, String> params = {};

    for (final segment in segments) {
      if (current.staticChildren.containsKey(segment)) {
        current = current.staticChildren[segment]!;
      } else if (current.paramChild != null) {
        params[current.paramName!] = segment;
        current = current.paramChild!;
      } else if (current.wildcardChild != null) {
        current = current.wildcardChild!;
        break;
      } else {
        return null;
      }
    }

    if (current.routes.isEmpty) return null;

    final routeData = current.routes[method];

    if (routeData == null) {
      return _SearchResult(null, params, isMethodNotAllowed: true, allowedMethods: current.routes.keys.toSet());
    }

    return _SearchResult(routeData, params);
  }

  List<String> _splitPath(String path) {
    return path.split('/').where((s) => s.isNotEmpty).toList();
  }
}

class _SearchResult {
  final Route? data;
  final Map<String, String> params;
  final bool isMethodNotAllowed;
  final Set<String> allowedMethods;

  _SearchResult(this.data, this.params, {this.isMethodNotAllowed = false, this.allowedMethods = const {}});
}
