import 'package:lyzor/src/models/router/node.dart';
import 'package:lyzor/src/models/router/search_result.dart';

class RouterHelper {
  static SearchResult? lookup(String method, String path, Node root) {
    Node current = root;
    final segments = splitPath(path);
    final Map<String, String> params = {};

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];

      if (current.staticChildren.containsKey(segment)) {
        current = current.staticChildren[segment]!;
      } else if (current.paramChild != null) {
        params[current.paramName!] = segment;
        current = current.paramChild!;
      } else if (current.wildcardChild != null) {
        params['*'] = segments.sublist(i).join('/');
        current = current.wildcardChild!;
        break;
      } else {
        return null;
      }
    }

    final routeData = current.routes[method];

    if (routeData == null) {
      if (current.routes.isNotEmpty) {
        return SearchResult(null, params, isMethodNotAllowed: true, allowedMethods: current.routes.keys.toSet());
      }

      if (current.wildcardChild != null && current.wildcardChild!.routes.containsKey(method)) {
        params['*'] = '';
        return SearchResult(current.wildcardChild!.routes[method], params);
      }

      return null;
    }

    return SearchResult(routeData, params);
  }

  static List<String> splitPath(String path) {
    return path.split('/').where((s) => s.isNotEmpty).toList();
  }
}
