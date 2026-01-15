part of 'lyzor_base.dart';

class Context {
  final Request request;
  final Response response;
  Map<String, dynamic> locals = {};

  Context(this.request, this.response);

  String get method => request.method;
  Uri get uri => request.uri;
  Map<String, String> get pathParams => request.pathParams;
  Map<String, String> get queryParams => request.queryParams;
  HttpHeaders get headers => request.headers;

  Future<String> get body => request.body;
  Future<Map<String, dynamic>> get json => request.json;

  Result jsonResult(Object data, {int status = HttpStatus.ok}) => Results.json(data, status: status);
  Result textResult(String text, {int status = HttpStatus.ok}) => Results.text(text, status: status);
}
