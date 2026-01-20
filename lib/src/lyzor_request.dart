import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lyzor/src/lyzor_exceptions.dart';
import 'package:mime/mime.dart';

class Request {
  final HttpRequest raw;
  Map<String, String> pathParams;
  final int maxBodySize;

  FormData? _formData;
  Map<String, dynamic>? _jsonCache;

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
    if (contentLength > maxBodySize) throw PayloadTooLargeException();

    final builder = BytesBuilder(copy: false);
    int received = 0;

    try {
      await for (final chunk in raw) {
        received += chunk.length;
        if (received > maxBodySize) throw PayloadTooLargeException();
        builder.add(chunk);
      }
    } catch (e) {
      throw BadRequestException('Error reading request body');
    }

    _bodyString = utf8.decode(builder.takeBytes());
    return _bodyString!;
  }

  Future<Map<String, dynamic>> get json async {
    if (_jsonCache != null) return _jsonCache!;

    final text = await body;
    try {
      _jsonCache = text.trim().isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;

      return _jsonCache!;
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

  Map<String, String> _parseHeaderParameters(String header) {
    final map = <String, String>{};
    final parts = header.split(';').map((s) => s.trim());
    for (final part in parts) {
      final idx = part.indexOf('=');
      if (idx != -1) {
        final key = part.substring(0, idx).trim();
        final value = part.substring(idx + 1).trim().replaceAll('"', '');
        map[key] = value;
      }
    }
    return map;
  }

  Future<FormData> get formData async {
    if (_formData != null) return _formData!;

    final contentType = raw.headers.contentType;
    if (contentType == null || contentType.primaryType != 'multipart' || contentType.subType != 'form-data') {
      throw BadRequestException('Request is not multipart/form-data');
    }

    final boundary = contentType.parameters['boundary'];
    if (boundary == null) throw BadRequestException('Missing boundary');

    final transformer = MimeMultipartTransformer(boundary);
    final parts = await transformer.bind(raw).toList();

    final Map<String, String> fields = {};
    final Map<String, List<UploadedFile>> files = {};

    for (final part in parts) {
      final contentDisposition = part.headers['content-disposition'] ?? '';
      final headerParams = _parseHeaderParameters(contentDisposition);
      final name = headerParams['name'];
      if (name == null) continue;

      final builder = BytesBuilder(copy: false);
      await for (final chunk in part) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();

      if (headerParams.containsKey('filename')) {
        final file = UploadedFile(
          name: name,
          filename: headerParams['filename'],
          contentType: part.headers['content-type'] ?? 'application/octet-stream',
          bytes: bytes,
        );
        files.putIfAbsent(name, () => []).add(file);
      } else {
        fields[name] = utf8.decode(bytes);
      }
    }

    _formData = FormData(fields, files);
    return _formData!;
  }
}

class UploadedFile {
  final String name;
  final String? filename;
  final String contentType;
  final List<int> bytes;

  UploadedFile({required this.name, this.filename, required this.contentType, required this.bytes});

  Future<File> save(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return await file.writeAsBytes(bytes);
  }
}

class FormData {
  final Map<String, String> fields;
  final Map<String, List<UploadedFile>> files;

  FormData(this.fields, this.files);
}
