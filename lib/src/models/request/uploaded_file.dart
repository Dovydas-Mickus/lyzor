import 'dart:io';

class UploadedFile {
  final String name;
  final String? filename;
  final String contentType;
  final Stream<List<int>> stream;

  UploadedFile({required this.name, this.filename, required this.contentType, required this.stream});

  Future<File> save(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);

    final sink = file.openWrite();
    try {
      await stream.pipe(sink);
    } finally {
      await sink.close();
    }
    return file;
  }
}
