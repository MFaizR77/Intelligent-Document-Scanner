// lib/utils/image_utils.dart
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ImageUtils {
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

  static Uint8List convertMatToUint8List(cv.Mat mat) {
    final result = cv.imencode('.jpg', mat);
    return result.$2;
  }
}
