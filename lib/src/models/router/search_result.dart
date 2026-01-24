import 'package:lyzor/src/models/router/route.dart';

class SearchResult {
  final Route? data;
  final Map<String, String> params;
  final bool isMethodNotAllowed;
  final Set<String> allowedMethods;

  SearchResult(this.data, this.params, {this.isMethodNotAllowed = false, this.allowedMethods = const {}});
}
