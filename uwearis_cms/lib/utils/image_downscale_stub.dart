import 'dart:typed_data';

/// Outside the browser (tests) nothing is resized.
Future<({Uint8List bytes, String contentType})?> downscale(
  Uint8List bytes,
  String contentType,
  int maxEdge,
) async => null;
