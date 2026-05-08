import 'dart:io';

class Response {
  final HttpResponse _res;
  final bool _poweredBy;
  bool _isCommitted = false;
  int get statusCode => _res.statusCode;

  HttpResponse get raw => _res;
  bool get isCommitted => _isCommitted;

  Response(this._res, {bool poweredBy = true}) : _poweredBy = poweredBy;

  void markCommitted() => _isCommitted = true;

  void status(int code) => _res.statusCode = code;

  void type(ContentType type) => _res.headers.contentType = type;

  void setHeader(String name, String value) => _res.headers.set(name, value);

  void prepare() {
    if (_poweredBy) setHeader('X-Powered-By', 'Lyzor');
  }

  void cookie(Cookie cookie) {
    if (_isCommitted) return;
    _res.cookies.add(cookie);
  }
}
