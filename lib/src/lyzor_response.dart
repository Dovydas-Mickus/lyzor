import 'dart:io';

class Response {
  final HttpResponse _res;
  int _statusCode = HttpStatus.ok;
  ContentType? _contentType;
  bool _isCommitted = false;

  HttpResponse get raw => _res;
  bool get isCommitted => _isCommitted;
  int get statusCode => _statusCode;

  Response(this._res);

  void markCommitted() => _isCommitted = true;

  Response status(int code) {
    if (_isCommitted) return this;
    _statusCode = code;
    _res.statusCode = code;
    return this;
  }

  Response type(ContentType type) {
    if (_isCommitted) return this;
    _contentType = type;
    _res.headers.contentType = type;
    return this;
  }

  Response setHeader(String name, String value) {
    if (_isCommitted) return this;
    _res.headers.set(name, value);
    return this;
  }

  void prepare() {
    _res.statusCode = _statusCode;
    if (_contentType != null) {
      _res.headers.contentType = _contentType;
    }
  }
}
