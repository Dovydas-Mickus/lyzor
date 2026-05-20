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
        ..expires = DateTime(1970)
        ..sameSite = SameSite.lax,
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
    applyState(res);
    res.type(ContentType.json);
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
    applyState(res);
    res.type(contentType ?? ContentType.text);
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
    applyState(res);
    res.type(ContentType.html);
    res.raw.write(content);
    await res.raw.close();
    res.markCommitted();
  }
}

class XmlResult extends TextResult {
  const XmlResult(super.content, {super.status, super.headers, super.cookies}) : super(contentType: null);

  @override
  XmlResult withCookie(Cookie cookie) =>
      XmlResult(content, status: status, headers: headers, cookies: [...cookies, cookie]);

  @override
  XmlResult withHeader(String name, String value) =>
      XmlResult(content, status: status, headers: {...headers, name: value}, cookies: cookies);

  @override
  XmlResult withStatus(int status) => XmlResult(content, status: status, headers: headers, cookies: cookies);

  @override
  Future<void> execute(Response res) async {
    applyState(res);
    res.type(ContentType('application', 'xml', charset: 'utf-8'));
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
    applyState(res);
    res.setHeader(HttpHeaders.locationHeader, url);
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
    applyState(res);
    res.type(mimeType);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    await file.openRead().pipe(res.raw);
    res.markCommitted();
  }
}

class NotModifiedResult extends Result {
  const NotModifiedResult({super.headers, super.cookies}) : super(status: 304);

  @override
  NotModifiedResult withStatus(int status) => this; // Status is fixed at 304
  @override
  NotModifiedResult withHeader(String name, String value) =>
      NotModifiedResult(headers: {...headers, name: value}, cookies: cookies);
  @override
  NotModifiedResult withCookie(Cookie cookie) => NotModifiedResult(headers: headers, cookies: [...cookies, cookie]);

  @override
  Future<void> execute(Response res) async {
    applyState(res);
    await res.raw.close();
    res.markCommitted();
  }
}

class StatusResult extends Result {
  /// Default to 204 No Content as it's the most common "empty" success status
  const StatusResult({super.status = HttpStatus.noContent, super.headers, super.cookies});

  @override
  StatusResult withStatus(int status) => StatusResult(status: status, headers: headers, cookies: cookies);

  @override
  StatusResult withHeader(String name, String value) =>
      StatusResult(status: status, headers: {...headers, name: value}, cookies: cookies);

  @override
  StatusResult withCookie(Cookie cookie) =>
      StatusResult(status: status, headers: headers, cookies: [...cookies, cookie]);

  @override
  Future<void> execute(Response res) async {
    applyState(res);
    await res.raw.close();
    res.markCommitted();
  }
}
