import 'dart:convert';
import 'dart:io';
import 'package:lyzor/src/models/request/form_data.dart';
import 'package:lyzor/src/models/request/uploaded_file.dart';
import 'package:mime/mime.dart';

class MultipartParser {
  static Future<FormData> parse(
    Stream<List<int>> stream,
    String boundary, {
    int? maxFiles,
    int? maxFields,
    int maxFieldSize = 1024 * 1024,
  }) async {
    final transformer = MimeMultipartTransformer(boundary);
    final parts = transformer.bind(stream);

    final Map<String, String> fields = {};
    final Map<String, List<UploadedFile>> files = {};
    int fileCount = 0;
    int fieldCount = 0;

    await for (final part in parts) {
      final cdRaw = part.headers['content-disposition'];
      if (cdRaw == null) continue;

      final cd = HeaderValue.parse(cdRaw);
      final params = cd.parameters;
      final name = params['name'];
      if (name == null) continue;

      final filename = _pickFilename(params);

      if (filename != null) {
        if (maxFiles != null && ++fileCount > maxFiles) {
          throw Exception('Maximum of $maxFiles file(s) allowed.');
        }

        files
            .putIfAbsent(name, () => [])
            .add(
              UploadedFile(
                name: name,
                filename: filename,
                contentType: part.headers['content-type'] ?? 'application/octet-stream',
                stream: part,
              ),
            );
      } else {
        if (maxFields != null && fields.containsKey(name) == false) {
          if (++fieldCount > maxFields) {
            throw Exception('Maximum of $maxFields text field(s) allowed.');
          }
        }

        final bytes = <int>[];
        await for (final chunk in part) {
          bytes.addAll(chunk);
          if (bytes.length > maxFieldSize) {
            throw Exception('Field "$name" exceeds limit of $maxFieldSize bytes.');
          }
        }
        fields[name] = utf8.decode(bytes);
      }
    }

    return FormData(fields, files);
  }

  static String? _pickFilename(Map<String, String?> params) {
    final fnStar = params['filename*'];
    if (fnStar != null && fnStar.isNotEmpty) {
      final decoded = _decodeFilenameStar(fnStar);
      if (decoded != null) return _sanitize(decoded);
    }

    final fn = params['filename'];
    if (fn != null && fn.isNotEmpty) return _sanitize(fn);

    return null;
  }

  static String _sanitize(String path) {
    return path.split(RegExp(r'[\\/]+')).last;
  }

  static String? _decodeFilenameStar(String v) {
    try {
      final segments = v.split("'");
      if (segments.length < 3) return null;

      final charset = segments[0].toLowerCase();
      final encodedText = segments.sublist(2).join("'");
      final bytes = _percentDecodeToBytes(encodedText);

      if (charset == 'utf-8' || charset == '') {
        return utf8.decode(bytes, allowMalformed: true);
      } else if (charset == 'iso-8859-1') {
        return String.fromCharCodes(bytes);
      }
    } catch (_) {}
    return null;
  }

  static List<int> _percentDecodeToBytes(String s) {
    final List<int> result = [];
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '%' && i + 2 < s.length) {
        final hex = s.substring(i + 1, i + 3);
        final val = int.tryParse(hex, radix: 16);
        if (val != null) {
          result.add(val);
          i += 2;
          continue;
        }
      }
      result.add(s.codeUnitAt(i));
    }
    return result;
  }
}
