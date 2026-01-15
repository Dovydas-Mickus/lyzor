import 'dart:convert';
import 'dart:io';

import 'package:lyzor/src/lyzor_exceptions.dart';

class Request {
  final HttpRequest raw;
  final Map<String, String> pathParams;
  final int maxBodySize;

  Request(this.raw, {this.pathParams = const {}, this.maxBodySize = 10485760});

  String get method => raw.method;
  Uri get uri => raw.uri;

  Map<String, String> get queryParams => uri.queryParameters;
  HttpHeaders get headers => raw.headers;

  String get ip => raw.connectionInfo?.remoteAddress.address ?? 'unknown';

  String? _bodyString;
  Future<String>? _bodyFuture;

  Future<String> get body {
    if (_bodyString != null) return Future.value(_bodyString!);
    if (_bodyFuture != null) return _bodyFuture!;

    _bodyFuture = _readBody();

    return _bodyFuture!;
  }

  Future<String> _readBody() async {
    final contentLength = raw.headers.contentLength;

    if (contentLength > maxBodySize) {
      throw PayloadTooLargeException();
    }

    final List<int> bytes = [];
    int received = 0;

    await for (final chunk in raw) {
      received += chunk.length;

      if (received > maxBodySize) {
        throw PayloadTooLargeException();
      }

      bytes.addAll(chunk);
    }

    _bodyString = utf8.decode(bytes);

    return _bodyString!;
  }

  Future<Map<String, dynamic>> get json async {
    final text = await body;
    try {
      return text.trim().isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw BadRequestException('Invalid JSON body');
    }
  }

  Future<Map<String, String>> get form async {
    final text = await body;
    if (text.trim().isEmpty) return {};
    return Uri.splitQueryString(text);
  }

  Map<String, String> get cookies => {for (final c in raw.cookies) c.name: c.value};
}
