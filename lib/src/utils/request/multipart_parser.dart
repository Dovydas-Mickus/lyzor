import 'dart:convert';

import 'package:lyzor/lyzor.dart';
import 'package:mime/mime.dart';

class MultipartParser {
  static Future<FormData> parse(Stream<List<int>> stream, String boundary, {int? maxFiles, int? maxFields}) async {
    final transformer = MimeMultipartTransformer(boundary);
    final parts = transformer.bind(stream);

    final Map<String, String> fields = {};
    final Map<String, List<UploadedFile>> files = {};
    int fileCount = 0;
    int fieldCount = 0;

    await for (final part in parts) {
      final header = _parseDisposition(part.headers['content-disposition'] ?? '');
      final name = header['name'];
      if (name == null) continue;

      if (header.containsKey('filename')) {
        if (maxFiles != null && ++fileCount > maxFiles) {
          throw BadRequestException('Maximum of $maxFiles file(s) allowed.');
        }

        files
            .putIfAbsent(name, () => [])
            .add(
              UploadedFile(
                name: name,
                filename: header['filename'],
                contentType: part.headers['content-type'] ?? 'application/octet-stream',
                stream: part,
              ),
            );
      } else {
        if (maxFields != null && ++fieldCount > maxFields) {
          throw BadRequestException('Maximum of $maxFields text field(s) allowed.');
        }
        fields[name] = utf8.decode(await part.expand((b) => b).toList());
      }
    }
    return FormData(fields, files);
  }

  static Map<String, String> _parseDisposition(String header) {
    final map = <String, String>{};
    for (final part in header.split(';')) {
      final pair = part.split('=');
      if (pair.length == 2) {
        map[pair[0].trim()] = pair[1].trim().replaceAll('"', '');
      }
    }
    return map;
  }
}
