part of 'lyzor_base.dart';

class Context {
  final Request request;
  final Response response;
  final Registry _registry;
  Map<String, dynamic> locals = {};

  Context(this.request, this.response, this._registry);

  String get method => request.method;
  Uri get uri => request.uri;
  Map<String, String> get pathParams => request.pathParams;
  Map<String, String> get queryParams => request.queryParams;
  HttpHeaders get headers => request.headers;

  Future<String> get body => request.body;
  Future<Map<String, dynamic>> get json => request.json;

  T read<T>() => _registry.get<T>();

  Result jsonResult(Object data, {int status = HttpStatus.ok}) => Results.json(data, status: status);
  Result textResult(String text, {int status = HttpStatus.ok}) => Results.text(text, status: status);

  void setCookie(
    String name,
    String value, {
    DateTime? expires,
    int? maxAge,
    String? domain,
    String path = '/',
    bool secure = false,
    bool httpOnly = true,
    SameSite sameSite = SameSite.lax,
  }) {
    final cookie = Cookie(name, value)
      ..expires = expires
      ..maxAge = maxAge
      ..domain = domain
      ..path = path
      ..secure = secure
      ..httpOnly = httpOnly
      ..sameSite = sameSite;

    response.cookie(cookie);
  }

  void clearCookie(String name, {String path = '/'}) {
    setCookie(name, '', path: path, maxAge: 0, expires: DateTime(1970));
  }
}
