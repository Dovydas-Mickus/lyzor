import 'lyzor_base.dart';

class _RouteData {
  final Handler handler;
  final List<Middleware> middlewares;
  final String method;

  _RouteData(this.method, this.handler, this.middlewares);
}

class _Node {
  final Map<String, _Node> staticChildren = {};

  _Node? paramChild;
  String? paramName;

  _Node? wildcardChild;

  final Map<String, _RouteData> routes = {};

  bool get isLeaf => routes.isNotEmpty;
}

class Router {
  final _Node _root = _Node();

  void addRoute(String method, String path, Handler handler, List<Middleware> middlewares) {
    _Node current = _root;
    final segments = _splitPath(path);

    for (final segment in segments) {
      if (segment.startsWith(':')) {
        // Parameter segment
        current.paramChild ??= _Node();
        current.paramName = segment.substring(1);
        current = current.paramChild!;
      } else if (segment == '*') {
        // Wildcard segment
        current.wildcardChild ??= _Node();
        current = current.wildcardChild!;
      } else {
        // Static segment
        current = current.staticChildren.putIfAbsent(segment, () => _Node());
      }
    }
    current.routes[method] = _RouteData(method, handler, middlewares);
  }

  _SearchResult? lookup(String method, String path) {
    _Node current = _root;
    final segments = _splitPath(path);
    final Map<String, String> params = {};

    for (final segment in segments) {
      // 1. Try static match (Highest priority)
      if (current.staticChildren.containsKey(segment)) {
        current = current.staticChildren[segment]!;
      }
      // 2. Try parameter match
      else if (current.paramChild != null) {
        params[current.paramName!] = segment;
        current = current.paramChild!;
      }
      // 3. Try wildcard match
      else if (current.wildcardChild != null) {
        current = current.wildcardChild!;
        break; // Wildcard consumes the rest
      } else {
        return null; // No match found
      }
    }

    if (current.routes.isEmpty) return null;

    final routeData = current.routes[method];

    // Check for Method Not Allowed
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
  final _RouteData? data;
  final Map<String, String> params;
  final bool isMethodNotAllowed;
  final Set<String> allowedMethods;

  _SearchResult(this.data, this.params, {this.isMethodNotAllowed = false, this.allowedMethods = const {}});
}
