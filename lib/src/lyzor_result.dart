import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'lyzor_response.dart';

abstract class Result {
  int get status;

  Future<void> execute(Response res);
}

class JsonResult implements Result {
  final Object data;

  @override
  final int status;
  final Map<String, String> headers;

  JsonResult(this.data, {this.status = HttpStatus.ok, this.headers = const {}});

  @override
  Future<void> execute(Response res) async {
    res.status(status).type(ContentType.json);
    headers.forEach(res.setHeader);
    res.prepare();

    res.raw.write(jsonEncode(data));
    await res.raw.close();
    res.markCommitted();
  }
}

class TextResult implements Result {
  final String text;

  @override
  final int status;
  final ContentType type;
  final Map<String, String> headers;

  TextResult(this.text, {this.status = HttpStatus.ok, ContentType? type, this.headers = const {}})
    : type = type ?? ContentType.text;

  @override
  Future<void> execute(Response res) async {
    res.status(status).type(type);
    headers.forEach(res.setHeader);
    res.prepare();

    res.raw.write(text);
    await res.raw.close();
    res.markCommitted();
  }
}

class FileResult implements Result {
  final File file;

  final int? _status;
  final ContentType? type;

  @override
  int get status => _status ?? HttpStatus.ok;

  FileResult(this.file, {int? status, this.type}) : _status = status;

  @override
  Future<void> execute(Response res) async {
    if (!await file.exists()) {
      await TextResult('File not found', status: HttpStatus.notFound).execute(res);
      return;
    }

    final resolvedType = type ?? ContentType.parse(lookupMimeType(file.path) ?? 'application/octet-stream');

    res.status(status).type(resolvedType);
    res.prepare();

    await file.openRead().pipe(res.raw);
    res.markCommitted();
  }
}

class RedirectResult implements Result {
  final String url;

  @override
  final int status;

  RedirectResult(this.url, {this.status = HttpStatus.found});

  @override
  Future<void> execute(Response res) async {
    res.status(status);
    res.setHeader(HttpHeaders.locationHeader, url);
    res.prepare();
    await res.raw.close();
    res.markCommitted();
  }
}

// Shortcut Factory
class Results {
  static Result json(Object data, {int status = HttpStatus.ok, Map<String, String> headers = const {}}) =>
      JsonResult(data, status: status, headers: headers);

  static Result text(String text, {int status = HttpStatus.ok, ContentType? type}) =>
      TextResult(text, status: status, type: type);

  static Result file(File file, {int? status, ContentType? type}) => FileResult(file, status: status, type: type);

  static Result redirect(String url, {int status = HttpStatus.found}) => RedirectResult(url, status: status);
}
