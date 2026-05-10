// lib/utils/image_utils.dart
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ImageUtils {
  static cv.Mat convertCameraImageToMat(CameraImage image) {
    // Basic conversion logic (needs adaptation based on YUV/NV21 format)
    // For now, return a placeholder Mat based on image planes
    if (image.format.group == ImageFormatGroup.yuv420) {
      // YUV to BGR conversion using opencv_dart
      final yPlane = image.planes[0].bytes;
      final yMat = cv.Mat.fromList(image.height, image.width, cv.MatType.CV_8UC1, yPlane);
      // NOTE: This is simplified. Proper YUV420 to BGR requires U and V planes.
      // But for edge detection, grayscale (Y plane) is often enough.
      return yMat;
    }
    
    // Fallback/dummy
    return cv.Mat.empty();
  }

  static Uint8List convertMatToUint8List(cv.Mat mat) {
    final success = cv.Cv2.imencode('.jpg', mat);
    return success.$2;
  }
}
