import 'dart:convert';
import 'dart:io';

import 'package:lyzor/src/lyzor_exceptions.dart';

class Request {
  final HttpRequest raw;
  final Map<String, String> pathParams;

  Request(this.raw, [this.pathParams = const {}]);

  String get method => raw.method;
  Uri get uri => raw.uri;

  Map<String, String> get queryParams => uri.queryParameters;
  HttpHeaders get headers => raw.headers;

  String get ip => raw.connectionInfo?.remoteAddress.address ?? 'unknown';

  String? _bodyString;
  Future<String>? _bodyFuture;

  Future<String> get body {
    final cached = _bodyString;
    if (cached != null) return Future.value(cached);

    final inflight = _bodyFuture;
    if (inflight != null) return inflight;

    final future = utf8.decoder.bind(raw).join().then((s) {
      _bodyString = s;
      return s;
    });

    _bodyFuture = future;
    return future;
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
