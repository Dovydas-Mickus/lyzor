import 'dart:io';
import 'lyzor_response.dart';

abstract class Result {
  Future<void> execute(Response res);
}

class JsonResult implements Result {
  final Object data;
  final int status;
  final Map<String, String> headers;

  JsonResult(this.data, {this.status = HttpStatus.ok, this.headers = const {}});

  @override
  Future<void> execute(Response res) async {
    headers.forEach(res.setHeader);
    await res.status(status).json(data);
  }
}

class TextResult implements Result {
  final String text;
  final int status;
  final ContentType type;
  final Map<String, String> headers;

  TextResult(this.text, {this.status = HttpStatus.ok, ContentType? type, this.headers = const {}})
    : type = type ?? ContentType.text;

  @override
  Future<void> execute(Response res) async {
    headers.forEach(res.setHeader);
    await res.send(text, status: status, type: type);
  }
}

class FileResult implements Result {
  final File file;
  final int? status;
  final ContentType? type;

  FileResult(this.file, {this.status, this.type});

  @override
  Future<void> execute(Response res) async {
    await res.file(file, status: status, type: type);
  }
}

class RedirectResult implements Result {
  final String url;
  final int status;

  RedirectResult(this.url, {this.status = HttpStatus.found});

  @override
  Future<void> execute(Response res) async {
    res.redirect(url, status: status);
  }
}

class EmptyResult implements Result {
  final int status;
  EmptyResult([this.status = HttpStatus.noContent]);

  @override
  Future<void> execute(Response res) async {
    await res.send('', status: status);
  }
}

class Results {
  static Result json(Object data, {int status = HttpStatus.ok, Map<String, String> headers = const {}}) =>
      JsonResult(data, status: status, headers: headers);

  static Result text(String text, {int status = HttpStatus.ok, ContentType? type}) =>
      TextResult(text, status: status, type: type ?? ContentType.text);

  static Result file(File file, {int? status, ContentType? type}) => FileResult(file, status: status, type: type);

  static Result redirect(String url, {int status = HttpStatus.found}) => RedirectResult(url, status: status);

  static Result empty([int status = HttpStatus.noContent]) => EmptyResult(status);
}
