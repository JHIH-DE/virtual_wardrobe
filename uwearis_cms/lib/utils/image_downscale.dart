import 'dart:typed_data';

import 'image_downscale_stub.dart'
    if (dart.library.js_interop) 'image_downscale_web.dart'
    as impl;

/// An image ready to upload: possibly smaller than the picked file.
typedef PreparedImage = ({Uint8List bytes, String contentType});

/// The longest edge a magazine photo needs: a full-screen slide on a large
/// phone is about 1300 × 2800 physical pixels.
const int maxUploadEdge = 2400;

/// Shrinks a photo whose longest edge is over [maxUploadEdge], so the App
/// doesn't download camera-size originals. PNG stays PNG (keeps the cut-outs'
/// transparency); JPEG and WebP become JPEG. Anything that can't be decoded
/// is uploaded as picked.
Future<PreparedImage> downscaleForUpload(
  Uint8List bytes,
  String contentType,
) async {
  try {
    return await impl.downscale(bytes, contentType, maxUploadEdge) ??
        (bytes: bytes, contentType: contentType);
  } catch (_) {
    return (bytes: bytes, contentType: contentType);
  }
}
