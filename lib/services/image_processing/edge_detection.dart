import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../config/pcd_params.dart';

class EdgeDetectionService {
  static const (int, int) _gaussianKernel = (5, 5);
  static const double _gaussianSigma = 1.5;

  static Map<String, dynamic> findDocumentCorners(cv.Mat input) {
    cv.setNumThreads(0);
    if (input.isEmpty) return {'corners': [], 'isPerfect': false};

    cv.Mat? gray;
    cv.Mat? blurred;
    cv.Mat? edges;
    cv.Mat? dilated;
    cv.Contours? contours;
    cv.Mat? kernel;

    try {
      gray = _toGrayscale(input);
      blurred = _applyGaussianBlur(gray);
      
      // 1. Threshold normal (50, 150) agar tidak terlalu peka pada tekstur novel/ramai
      edges = cv.canny(blurred, 50, 150);

      // 2. DILATE: Menebalkan dan menyambungkan tepi kertas yang samar
      kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
      dilated = cv.dilate(edges, kernel);

      final contourResult = cv.findContours(
        dilated,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );
      contours = contourResult.$1;

      if (contours.isEmpty) return {'corners': [], 'isPerfect': false};

      // 3. SET BATAS MINIMAL 5% (Fokus ke dokumen riil, hiraukan debu/pantulan lampu)
      final minArea = (input.cols * input.rows) * 0.05;
      double largestArea = minArea;
      cv.Contour? largestContour;

      for (final contour in contours) {
        final area = cv.contourArea(contour);
        if (area > largestArea) {
          largestArea = area;
          largestContour = contour;
        }
      }

      if (largestContour == null) return {'corners': [], 'isPerfect': false};

      final perimeter = cv.arcLength(largestContour, true);
      final approx = cv.approxPolyDP(largestContour, 0.03 * perimeter, true);

      List<cv.Point> points;
      bool isPerfect = false;

      if (approx.length == 4) {
        // Jika menemukan 4 sudut pas, set isPerfect jadi TRUE (Hijau)
        points = approx.map((point) => cv.Point(point.x, point.y)).toList();
        isPerfect = true; 
      } else {
        // FALLBACK: Kurung objek dengan kotak merah fleksibel
        final rotatedRect = cv.minAreaRect(largestContour);
        final box = cv.boxPoints(rotatedRect);
        points = box.toList().map((p) => cv.Point(p.x.toInt(), p.y.toInt())).toList();
      }

      approx.dispose();
      
      // 4. Mencegah garis menyilang dengan sorting baru
      final ordered = _orderCorners(points);

      return {
        'corners': ordered.map((p) => {'x': p.x.toDouble(), 'y': p.y.toDouble()}).toList(),
        'isPerfect': isPerfect,
      };
    } catch (error) {
      if (PcdParams.logProcessingTime) {
        debugPrint('[EdgeDetection] Error: $error');
      }
      return {'corners': [], 'isPerfect': false};
    } finally {
      contours?.dispose();
      kernel?.dispose();
      dilated?.dispose();
      edges?.dispose();
      blurred?.dispose();
      gray?.dispose();
    }
  }

  // ALGORITMA SORTING SUM & DIFFERENCE (Anti Jam-Pasir)
  static List<cv.Point> _orderCorners(List<cv.Point> pts) {
    if (pts.length != 4) return pts;

    // Titik Kiri-Atas (Top-Left) punya jumlah X+Y terkecil
    // Titik Kanan-Bawah (Bottom-Right) punya jumlah X+Y terbesar
    pts.sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final tl = pts.first;
    final br = pts.last;

    // Sisa 2 titik diurutkan pakai selisih Y-X
    // Kanan-Atas (Top-Right) punya selisih terkecil
    // Kiri-Bawah (Bottom-Left) punya selisih terbesar
    final remaining = [pts[1], pts[2]];
    remaining.sort((a, b) => (a.y - a.x).compareTo(b.y - b.x));
    final tr = remaining.first;
    final bl = remaining.last;

    return [tl, tr, br, bl];
  }

  static cv.Mat _toGrayscale(cv.Mat input) {
    try {
      if (input.channels == 3) {
        return cv.cvtColor(input, cv.COLOR_BGR2GRAY);
      } else if (input.channels == 1) {
        return input.clone();
      } else {
        return cv.cvtColor(input, cv.COLOR_BGR2GRAY);
      }
    } catch (_) {
      return cv.Mat.empty();
    }
  }

  static cv.Mat _applyGaussianBlur(cv.Mat gray) {
    try {
      return cv.gaussianBlur(gray, _gaussianKernel, _gaussianSigma);
    } catch (_) {
      return cv.Mat.empty();
    }
  }
}