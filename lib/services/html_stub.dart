// Stub definitions for non-web platforms to satisfy conditional imports.
// These are NO-OP implementations; they should never be executed because
// usages are always guarded by kIsWeb in the calling code.
import 'dart:async';

class Blob {
  Blob(List<dynamic> parts, [String? type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String? download;
  AnchorElement({String? href});
  void click() {}
  void remove() {}
}

class BodyElement {
  void append(dynamic element) {}
}

class Document {
  BodyElement? body = BodyElement();
}

// Provide a top-level document to match dart:html API surface used.
final document = Document();

class FileUploadInputElement {
  List<File>? files;
  String? accept;
  void click() {}
  // Empty stream; onChange will never fire on non-web.
  Stream<Event> get onChange => const Stream<Event>.empty();
}

class File {
  final String name;
  File(this.name);
}

class FileReader {
  dynamic result;
  void readAsArrayBuffer(File file) {}
  Stream<Event> get onLoad => const Stream<Event>.empty();
}

class Event {}
