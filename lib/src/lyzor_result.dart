import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'lyzor_response.dart';

abstract class Result {
  final int status;
  final Map<String, String> headers;
  final List<Cookie> cookies;

  const Result({this.status = HttpStatus.ok, this.headers = const {}, this.cookies = const []});

  Result withStatus(int status);
  Result withHeader(String name, String value);
  Result withCookie(Cookie cookie);

  Result expireCookie(String name, {String path = '/'}) {
    return withCookie(
      Cookie(name, '')
        ..path = path
        ..maxAge = 0
        ..expires = DateTime(1970),
    );
  }

  Future<void> execute(Response res);

  void applyState(Response res) {
    res.status(status);
    headers.forEach(res.setHeader);
    for (var cookie in cookies) {
      res.raw.cookies.add(cookie);
    }
    res.prepare();
  }
}

class JsonResult extends Result {
  final Object data;

  const JsonResult(this.data, {super.status, super.headers, super.cookies});

  @override
  JsonResult withCookie(Cookie cookie) =>
      JsonResult(data, status: status, headers: headers, cookies: [...cookies, cookie]);

  @override
  JsonResult withHeader(String name, String value) =>
      JsonResult(data, status: status, headers: {...headers, name: value}, cookies: cookies);

  @override
  JsonResult withStatus(int status) => JsonResult(data, status: status, headers: headers, cookies: cookies);

  @override
  Future<void> execute(Response res) async {
    res.status(status);
    res.type(ContentType.json);
    headers.forEach(res.setHeader);
    res.prepare();
    res.raw.write(jsonEncode(data));
    await res.raw.close();
    res.markCommitted();
  }
}

class TextResult extends Result {
  final String content;
  final ContentType? contentType;

  const TextResult(this.content, {this.contentType, super.status, super.headers, super.cookies});

  @override
  TextResult withCookie(Cookie cookie) =>
      TextResult(content, status: status, headers: headers, cookies: [...cookies, cookie]);

  @override
  TextResult withHeader(String name, String value) =>
      TextResult(content, status: status, headers: {...headers, name: value}, cookies: cookies);

  @override
  TextResult withStatus(int status) => TextResult(content, status: status, headers: headers, cookies: cookies);

  @override
  Future<void> execute(Response res) async {
    res.status(status);
    res.type(contentType ?? ContentType.text);
    headers.forEach(res.setHeader);
    res.prepare();
    res.raw.write(content);
    await res.raw.close();
    res.markCommitted();
  }
}

class HtmlResult extends TextResult {
  const HtmlResult(super.content, {super.status, super.headers, super.cookies}) : super(contentType: null);

  @override
  HtmlResult withCookie(Cookie cookie) =>
      HtmlResult(content, status: status, headers: headers, cookies: [...cookies, cookie]);

  @override
  HtmlResult withHeader(String name, String value) =>
      HtmlResult(content, status: status, headers: {...headers, name: value}, cookies: cookies);

  @override
  HtmlResult withStatus(int status) => HtmlResult(content, status: status, headers: headers, cookies: cookies);

  @override
  Future<void> execute(Response res) async {
    res.status(status);
    res.type(ContentType.html);
    headers.forEach(res.setHeader);
    res.prepare();
    res.raw.write(content);
    await res.raw.close();
    res.markCommitted();
  }
}

class RedirectResult extends Result {
  final String url;

  const RedirectResult(this.url, {super.status = HttpStatus.found, super.headers, super.cookies});

  @override
  RedirectResult withCookie(Cookie cookie) =>
      RedirectResult(url, status: status, headers: headers, cookies: [...cookies, cookie]);

  @override
  RedirectResult withHeader(String name, String value) =>
      RedirectResult(url, status: status, headers: {...headers, name: value}, cookies: cookies);

  @override
  RedirectResult withStatus(int status) => RedirectResult(url, status: status, headers: headers, cookies: cookies);

  @override
  Future<void> execute(Response res) async {
    res.status(status);
    res.setHeader(HttpHeaders.locationHeader, url);
    headers.forEach(res.setHeader);
    res.prepare();
    await res.raw.close();
    res.markCommitted();
  }
}

class FileResult extends Result {
  final File file;
  final ContentType? contentType;

  const FileResult(this.file, {this.contentType, super.status, super.headers, super.cookies});

  @override
  FileResult withCookie(Cookie cookie) =>
      FileResult(file, status: status, headers: headers, cookies: [...cookies, cookie]);

  @override
  FileResult withHeader(String name, String value) =>
      FileResult(file, status: status, headers: {...headers, name: value}, cookies: cookies);

  @override
  FileResult withStatus(int status) => FileResult(file, status: status, headers: headers, cookies: cookies);

  @override
  Future<void> execute(Response res) async {
    if (!await file.exists()) {
      await TextResult('File not found', status: HttpStatus.notFound).execute(res);
      return;
    }

    final mimeType = contentType ?? ContentType.parse(lookupMimeType(file.path) ?? 'application/octet-stream');

    res.status(status);
    res.type(mimeType);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    headers.forEach(res.setHeader);
    res.prepare();

    await file.openRead().pipe(res.raw);
    res.markCommitted();
  }
}

class NotModified extends Result {
  const NotModified({super.headers, super.cookies}) : super(status: 304);

  @override
  NotModified withStatus(int status) => this; // Status is fixed at 304
  @override
  NotModified withHeader(String name, String value) =>
      NotModified(headers: {...headers, name: value}, cookies: cookies);
  @override
  NotModified withCookie(Cookie cookie) => NotModified(headers: headers, cookies: [...cookies, cookie]);

  @override
  Future<void> execute(Response res) async {
    applyState(res);
    res.markCommitted();
  }
}
