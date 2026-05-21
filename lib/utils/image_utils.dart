import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ImageUtils {
  /// Konversi CameraImage realtime → grayscale Mat (Y-plane only).
  /// Cocok untuk pipeline deteksi tepi yang tidak butuh warna.
  static cv.Mat convertCameraImageToMat(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420 &&
        image.planes.isNotEmpty) {
      final yPlane = image.planes[0];
      return convertYPlaneToMat(
        bytes: yPlane.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: yPlane.bytesPerRow,
      );
    }

    return cv.Mat.empty();
  }

  static cv.Mat convertYPlaneToMat({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
  }) {
    if (bytesPerRow == width) {
      return cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, bytes);
    }

    final packed = Uint8List(width * height);
    for (var row = 0; row < height; row++) {
      final srcOffset = row * bytesPerRow;
      final dstOffset = row * width;
      packed.setRange(dstOffset, dstOffset + width, bytes, srcOffset);
    }

    return cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, packed);
  }

  /// Encode Mat ke JPEG bytes (in-memory). Dipakai untuk preview thumbnail.
  static Uint8List convertMatToUint8List(cv.Mat mat) {
    final result = cv.imencode('.jpg', mat);
    return result.$2;
  }

  // ---------- File-based helpers (capture path) ----------

  /// Load JPG/PNG dari path → BGR color Mat (3 channel).
  static cv.Mat loadJpegToBgrMat(String path) {
    return cv.imread(path, flags: cv.IMREAD_COLOR);
  }

  /// Save Mat ke JPG. Mat boleh grayscale (1 ch) atau BGR (3 ch).
  /// Return true kalau sukses tulis file.
  static Future<bool> saveMatToJpeg(
    cv.Mat mat,
    String path, {
    int quality = 92,
  }) async {
    final params = cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, quality]);
    try {
      final encoded = cv.imencode('.jpg', mat, params: params);
      if (!encoded.$1) return false;
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(encoded.$2);
      return true;
    } finally {
      params.dispose();
    }
  }

  /// Resize agar dimensi terpanjang ≤ [maxLongSide] tanpa mengubah aspek.
  /// Mengembalikan Mat baru; caller bertanggung jawab dispose-nya.
  static cv.Mat downscaleLongSide(cv.Mat src, int maxLongSide) {
    final w = src.cols;
    final h = src.rows;
    final longSide = w >= h ? w : h;
    if (longSide <= maxLongSide) {
      return src.clone();
    }
    final scale = maxLongSide / longSide;
    final newW = (w * scale).round();
    final newH = (h * scale).round();
    return cv.resize(src, (newW, newH), interpolation: cv.INTER_AREA);
  }
}
