import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Null when the image is already small enough.
Future<({Uint8List bytes, String contentType})?> downscale(
  Uint8List bytes,
  String contentType,
  int maxEdge,
) async {
  final source = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: contentType),
  );
  final bitmap = await web.window.createImageBitmap(source).toDart;
  try {
    final longest = math.max(bitmap.width, bitmap.height);
    if (longest <= maxEdge) return null;
    final scale = maxEdge / longest;
    final width = (bitmap.width * scale).round();
    final height = (bitmap.height * scale).round();
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D
      ..imageSmoothingQuality = 'high';
    context.drawImage(bitmap, 0, 0, width, height);
    final outType = contentType == 'image/png' ? 'image/png' : 'image/jpeg';
    final done = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? blob) => done.complete(blob)).toJS,
      outType,
      0.88.toJS,
    );
    final blob = await done.future;
    if (blob == null) return null;
    final buffer = await blob.arrayBuffer().toDart;
    return (bytes: buffer.toDart.asUint8List(), contentType: outType);
  } finally {
    bitmap.close();
  }
}
