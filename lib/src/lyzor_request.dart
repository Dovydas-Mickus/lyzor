import 'dart:convert';
import 'dart:io';

import '../lyzor.dart';
import 'utils/request/multipart_parser.dart';
import 'utils/request/request_body.dart';

class Request {
  final HttpRequest raw;
  final int maxBodySize;
  Map<String, String> pathParams;

  String? _bodyCache;
  Map<String, dynamic>? _jsonCache;
  FormData? _formDataCache;

  Request(this.raw, {this.pathParams = const {}, this.maxBodySize = 10485760});

  String get method => raw.method;
  Uri get uri => raw.uri;
  Map<String, String> get queryParams => uri.queryParameters;
  HttpHeaders get headers => raw.headers;
  String get ip => raw.connectionInfo?.remoteAddress.address ?? 'unknown';

  /// Returns the real client IP, reading X-Forwarded-For only when the
  /// direct connection IP is in [trustedProxies].
  String realIp({List<String> trustedProxies = const []}) {
    final direct = ip;
    if (trustedProxies.isEmpty || !trustedProxies.contains(direct)) return direct;
    final forwarded = raw.headers.value('X-Forwarded-For');
    if (forwarded == null) return direct;
    return forwarded.split(',').first.trim();
  }
  Map<String, String> get cookies => {for (final c in raw.cookies) c.name: c.value};

  Future<String> get body async {
    if (_bodyCache != null) return _bodyCache!;
    final requestBody = await RequestBody.getBody(raw, maxBodySize);

    return _bodyCache = requestBody;
  }

  Future<Map<String, dynamic>> get json async {
    if (_jsonCache != null) return _jsonCache!;
    final text = await body;
    try {
      return _jsonCache = text.trim().isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw BadRequestException('Invalid JSON body');
    }
  }

  Future<String> get jsonString async {
    final text = await body;
    try {
      if (text.trim().isNotEmpty) jsonDecode(text);
      return text;
    } catch (_) {
      throw BadRequestException('Invalid JSON body');
    }
  }

  Future<Map<String, String>> get form async => Uri.splitQueryString(await body);

  Future<FormData> get formData => getFormData();

  Future<FormData> getFormData({int? maxFiles, int? maxFields}) async {
    if (_formDataCache != null) return _formDataCache!;

    final contentType = headers.contentType;
    if (contentType == null || contentType.subType != 'form-data') {
      throw BadRequestException('Request is not multipart/form-data');
    }

    final boundary = contentType.parameters['boundary'];
    if (boundary == null) throw BadRequestException('Missing boundary');

    final stream = RequestBody.limitedStream(raw, maxBodySize);
    return _formDataCache = await MultipartParser.parse(stream, boundary, maxFiles: maxFiles, maxFields: maxFields);
  }
}
