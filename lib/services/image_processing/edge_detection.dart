// lib/services/image_processing/edge_detection.dart
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../config/pcd_params.dart';

class EdgeDetectionService {
  /// Versi cepat untuk realtime stream (Y-plane grayscale).
  /// Pakai profile [PcdParams.auto] supaya tidak tergantung mode user.
  static List<cv.Point> findDocumentCorners(cv.Mat input) =>
      findDocumentCornersWith(input, PcdParams.auto);

  /// Versi yang menerima profile eksplisit, dipakai pada jalur capture
  /// hi-res yang tahu mode dokumen yang user pilih.
  static List<cv.Point> findDocumentCornersWith(
    cv.Mat input,
    PcdProfile profile,
  ) {
    if (input.isEmpty) return [];

    cv.Mat? gray;
    cv.Mat? blurred;
    cv.Mat? edges;
    cv.Contours? contours;
    cv.VecVec4i? hierarchy;
    cv.VecPoint? bestApprox;

    try {
      gray = input.channels == 3
          ? cv.cvtColor(input, cv.COLOR_BGR2GRAY)
          : input.clone();
      final ksize = profile.gaussianKernel | 1; // pastikan ganjil
      blurred = cv.gaussianBlur(gray, (ksize, ksize), profile.gaussianSigma);
      edges = cv.canny(
        blurred,
        profile.cannyThreshold1,
        profile.cannyThreshold2,
      );

      final contourResult = cv.findContours(
        edges,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );
      contours = contourResult.$1;
      hierarchy = contourResult.$2;

      final imageArea = (input.cols * input.rows).toDouble();
      var maxArea = profile.minContourAreaRatio * imageArea;

      for (final contour in contours) {
        final area = cv.contourArea(contour);
        if (area <= maxArea) {
          continue;
        }

        final epsilon = 0.02 * cv.arcLength(contour, true);
        final approx = cv.approxPolyDP(contour, epsilon, true);
        if (approx.length == 4) {
          bestApprox?.dispose();
          bestApprox = approx;
          maxArea = area;
        } else {
          approx.dispose();
        }
      }

      if (bestApprox == null) {
        return [];
      }

      final points = bestApprox.map((p) => cv.Point(p.x, p.y)).toList();
      return _orderCorners(points);
    } finally {
      bestApprox?.dispose();
      hierarchy?.dispose();
      contours?.dispose();
      edges?.dispose();
      blurred?.dispose();
      gray?.dispose();
    }
  }

  static List<cv.Point> _orderCorners(List<cv.Point> pts) {
    if (pts.length != 4) return pts;

    pts.sort((a, b) => a.x.compareTo(b.x));

    final leftMost = [pts[0], pts[1]]..sort((a, b) => a.y.compareTo(b.y));
    final rightMost = [pts[2], pts[3]]..sort((a, b) => a.y.compareTo(b.y));

    final tl = leftMost[0];
    final bl = leftMost[1];
    final tr = rightMost[0];
    final br = rightMost[1];

    return [tl, tr, br, bl];
  }
}
