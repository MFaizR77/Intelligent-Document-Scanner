// lib/services/image_processing/enhancement.dart
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../config/pcd_params.dart';

class EnhancementService {
  static cv.Mat enhanceDocument(cv.Mat input) {
    if (input.isEmpty) return input.clone();

    cv.Mat? gray;
    cv.Mat? denoised;
    cv.CLAHE? clahe;
    cv.Mat? equalized;
    cv.Mat? binary;
    cv.Mat? kernel;
    cv.Mat? opened;

    try {
      gray = input.channels == 3
          ? cv.cvtColor(input, cv.COLOR_BGR2GRAY)
          : input.clone();
      denoised = cv.fastNlMeansDenoising(gray, h: 10);
      clahe = cv.createCLAHE(
        clipLimit: PcdParams.claheClipLimit,
        tileGridSize: (8, 8),
      );
      equalized = clahe.apply(denoised);
      binary = cv.adaptiveThreshold(
        equalized,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY_INV,
        PcdParams.adaptiveBlockSize,
        PcdParams.adaptiveC,
      );
      kernel = cv.getStructuringElement(cv.MORPH_RECT, (2, 2));
      opened = cv.morphologyEx(binary, cv.MORPH_OPEN, kernel);

      return PcdParams.invertOutput ? cv.bitwiseNOT(opened) : opened.clone();
    } finally {
      opened?.dispose();
      kernel?.dispose();
      binary?.dispose();
      equalized?.dispose();
      clahe?.dispose();
      denoised?.dispose();
      gray?.dispose();
    }
  }
}
