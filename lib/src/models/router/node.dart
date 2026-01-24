import 'package:lyzor/src/models/router/route.dart';

class Node {
  final Map<String, Node> staticChildren = {};

  Node? paramChild;
  String? paramName;

  Node? wildcardChild;

  final Map<String, Route> routes = {};

  bool get isLeaf => routes.isNotEmpty;
}
