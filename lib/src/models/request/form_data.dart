import 'package:lyzor/src/models/request/uploaded_file.dart';

class FormData {
  final Map<String, String> fields;
  final Map<String, List<UploadedFile>> files;

  FormData(this.fields, this.files);
}
