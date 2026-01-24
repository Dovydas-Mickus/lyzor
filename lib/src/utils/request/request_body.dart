import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lyzor/lyzor.dart';

class RequestBody {
  static Future<String> getBody(HttpRequest raw, int maxBodySize) async {
    if (raw.contentLength > maxBodySize) throw ContentTooLargeException();

    final builder = BytesBuilder(copy: false);
    int received = 0;

    try {
      await for (final chunk in raw) {
        received += chunk.length;
        if (received > maxBodySize) throw ContentTooLargeException();
        builder.add(chunk);
      }
      return utf8.decode(builder.takeBytes());
    } on HttpException {
      rethrow;
    } catch (e) {
      throw BadRequestException('Error reading request body');
    }
  }
}
