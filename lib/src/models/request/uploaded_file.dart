class UploadedFile {
  final String name;
  final String? filename;
  final String contentType;
  final Stream<List<int>> stream;

  UploadedFile({required this.name, this.filename, required this.contentType, required this.stream});
}
