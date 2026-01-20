part of 'lyzor_base.dart';

class Context {
  final Request request;
  final Registry _registry;
  Map<String, dynamic> locals = {};

  Context(this.request, this._registry);

  String get method => request.method;
  Uri get uri => request.uri;
  Map<String, String> get pathParams => request.pathParams;
  Map<String, String> get queryParams => request.queryParams;
  HttpHeaders get headers => request.headers;

  Future<String> get body => request.body;
  Future<Map<String, dynamic>> get json => request.json;

  static Context get current {
    final context = Zone.current[#lyzor_context];

    if (context == null) {
      throw StateError('Context.current accessed outside of a request zone.');
    }

    return context as Context;
  }

  T read<T>() => _registry.get<T>();
}
