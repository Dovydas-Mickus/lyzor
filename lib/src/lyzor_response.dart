import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';

class Response {
  final HttpResponse _res;
  int _statusCode = HttpStatus.ok;
  ContentType? _contentType;
  bool _headersSent = false;
  final Map<String, String> _extraHeaders = {};
  bool _isCommitted = false;
  bool get isCommitted => _headersSent || _isCommitted;

  Response(this._res);

  int get statusCode => _statusCode;

  void _commit() {
    if (_isCommitted) return;
    _isCommitted = true;
  }

  void _ensureNotCommitted() {
    if (isCommitted) {
      throw StateError('Response already committed (headers sent).');
    }
  }

  Response status(int code) {
    _statusCode = code;
    return this;
  }

  Response type(ContentType type) {
    _contentType = type;
    return this;
  }

  Response header(String name, String value) {
    _extraHeaders[name] = value;
    return this;
  }

  void _sendHeaders() {
    if (!_headersSent) {
      _res.statusCode = _statusCode;
      _res.headers.contentType = _contentType ?? ContentType.text;

      _extraHeaders.forEach((name, value) {
        _res.headers.set(name, value);
      });

      _headersSent = true;
    }
  }

  @Deprecated('Handlers now return a value instead')
  Future<void> send(Object body, {int? status, ContentType? type}) async {
    _ensureNotCommitted();
    _commit();

    if (status != null) _statusCode = status;
    if (type != null) _contentType = type;

    _sendHeaders();

    if (body is String) {
      _res.write(body);
    } else if (body is List<int>) {
      _res.add(body);
    } else if (body is Stream<List<int>>) {
      await _res.addStream(body);
    } else {
      _res.write(body.toString());
    }

    await _res.close();
  }

  @Deprecated('Handlers now return a value instead')
  Future<void> json(Object data, {int? status}) async {
    await send(jsonEncode(data), status: status, type: ContentType.json);
  }

  Future<void> file(File file, {int? status, ContentType? type}) async {
    if (!await file.exists()) {
      await send('File not found', status: HttpStatus.notFound);
      return;
    }

    if (status != null) _statusCode = status;

    if (type != null) {
      _contentType = type;
    } else {
      _contentType ??= ContentType.parse(lookupMimeType(file.path) ?? 'application/octet-stream');
    }

    _sendHeaders();

    await file.openRead().pipe(_res);
    await _res.close();
  }

  void redirect(String url, {int status = HttpStatus.found}) {
    _res.headers.set(HttpHeaders.locationHeader, url);
    _res.statusCode = status;
    _res.close();
    _headersSent = true;
  }

  void setHeader(String name, String value) {
    if (isCommitted) return;

    _res.headers.set(name, value);
    _extraHeaders[name] = value;
  }
}
