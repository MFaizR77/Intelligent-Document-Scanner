import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../config/pcd_params.dart';

/// Detects the four corner landmarks of a document in a camera frame using
/// a pure OpenCV pipeline (no external ML models).
class EdgeDetectionService {
  // Maximum width of the downscaled working frame. Downscaling destroys
  // high-frequency details (text, patterns) while preserving macro structure
  // (document boundary), and makes all subsequent operations faster.
  static const int _maxProcessingWidth = 500;

  // Bilateral filter parameters. Unlike Gaussian blur, bilateral filtering
  // smooths noise inside the document area while preserving sharp intensity
  // transitions at the document-background boundary.
  static const int _bilateralD = 9;
  static const double _bilateralSigmaColor = 75.0;
  static const double _bilateralSigmaSpace = 75.0;

  // Morphological closing kernel. MORPH_CLOSE (dilate → erode) bridges small
  // gaps in the Canny output, forming a closed outer contour that prevents
  // findContours from penetrating the document interior (e.g. text blocks).
  static const (int, int) _closingKernelSize = (7, 7);

  // Valid aspect-ratio range for real-world documents (A4=1.41, F4=1.37,
  // ID card≈1.59, B5=1.41). Contours outside this range are rejected.
  static const double _minAspectRatio = 1.2;
  static const double _maxAspectRatio = 1.9;

  /// Finds the four corner points of the largest document-like contour in [input].
  ///
  /// [rotateCode] is an optional `cv.ROTATE_*` constant. When provided, the
  /// downscaled frame is rotated **after** resize so that the rotation is
  /// performed on a small matrix (~500 px), keeping overhead near zero.
  ///
  /// Returns a map with:
  /// - `corners` — list of `{x, y}` maps in original-frame pixel coordinates.
  /// - `isPerfect` — true only when a convex quadrilateral with a valid aspect
  ///   ratio is found.
  /// - `processedWidth` / `processedHeight` — frame dimensions after rotation,
  ///   used by the caller to normalise corners to the [0, 1] ratio space.
  /// - `rotatedMat` — full-resolution [cv.Mat] after rotation, required by
  ///   [PerspectiveTransformService]. **Ownership is transferred to the caller**,
  ///   which must dispose it after use.
  static Map<String, dynamic> findDocumentCorners(
    cv.Mat input, {
    int? rotateCode,
  }) {
    cv.setNumThreads(0);
    if (input.isEmpty) return {'corners': [], 'isPerfect': false};

    cv.Mat? smallMat;
    cv.Mat? rotatedSmall;
    cv.Mat? gray;
    cv.Mat? blurred;
    cv.Mat? edges;
    cv.Mat? closed;
    cv.Contours? contours;
    cv.Mat? closingKernel;

    try {
      // --- Downscale ---
      final double scale = input.cols > _maxProcessingWidth
          ? _maxProcessingWidth / input.cols
          : 1.0;
      final int smallW = (input.cols * scale).round();
      final int smallH = (input.rows * scale).round();
      // INTER_AREA provides natural anti-aliasing during downscaling.
      smallMat = cv.resize(input, (smallW, smallH), interpolation: cv.INTER_AREA);

      // --- Rotate after downscale (performance optimisation) ---
      final cv.Mat processTarget;
      if (rotateCode != null) {
        rotatedSmall = cv.rotate(smallMat, rotateCode);
        processTarget = rotatedSmall;
      } else {
        processTarget = smallMat;
      }
      final int processedW = processTarget.cols;
      final int processedH = processTarget.rows;

      // --- Contrast stretching ---
      // NORM_MINMAX forces the full 0-255 intensity range, making low-contrast
      // documents (e.g. coloured ID cards on a similarly-toned surface) stand
      // out clearly against the background before edge detection.
      gray = _toGrayscale(processTarget);
      cv.normalize(gray, gray, alpha: 0, beta: 255, normType: cv.NORM_MINMAX);

      // --- Edge-preserving noise reduction ---
      blurred = _applyBilateralFilter(gray);

      // --- Canny edge detection ---
      // Lower thresholds (30, 100) improve recall for faint edges at document
      // corners, such as those on laminated or glossy ID cards.
      edges = cv.canny(blurred, 30, 100);

      // --- Morphological closing ---
      // Bridges discontinuities in the outer document boundary produced by
      // Canny, creating a sealed perimeter that blocks RETR_EXTERNAL from
      // descending into the document interior.
      closingKernel = cv.getStructuringElement(cv.MORPH_RECT, _closingKernelSize);
      closed = cv.morphologyEx(edges, cv.MORPH_CLOSE, closingKernel);

      // --- Contour detection ---
      final contourResult = cv.findContours(
        closed,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );
      contours = contourResult.$1;

      if (contours.isEmpty) return {'corners': [], 'isPerfect': false};

      // Reject contours smaller than 5 % of the working frame area.
      final minArea = (processedW * processedH) * 0.05;
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
        points = approx.map((p) => cv.Point(p.x, p.y)).toList();
        isPerfect = true;
      } else {
        // Fallback: derive a quadrilateral from the minimum-area bounding rect.
        final rotatedRect = cv.minAreaRect(largestContour);
        final box = cv.boxPoints(rotatedRect);
        points = box.toList().map((p) => cv.Point(p.x.toInt(), p.y.toInt())).toList();
      }

      // --- Geometric validation (runs only when approxPolyDP found 4 pts) ---

      // Aspect-ratio check: use minAreaRect so that tilted documents are
      // measured along their actual orientation, not their axis-aligned bbox.
      if (isPerfect) {
        final rect = cv.minAreaRect(largestContour);
        final w = rect.size.width;
        final h = rect.size.height;
        final ratio = w > h ? w / h : h / w; // always ≥ 1.0, orientation-agnostic
        if (ratio < _minAspectRatio || ratio > _maxAspectRatio) {
          isPerfect = false;
        }
      }

      // Convexity check: a flat physical document always appears as a convex
      // polygon from the camera's perspective; a concave hull indicates a
      // non-document object.
      if (isPerfect && approx.length == 4) {
        if (!cv.isContourConvex(approx)) {
          isPerfect = false;
        }
      }

      approx.dispose();

      // --- Scale coordinates back to original-frame resolution ---
      // The scale factor is derived from the input width before rotation, so
      // it remains valid regardless of the rotation angle.
      final double inverseScale = 1.0 / scale;
      final scaledPoints = points
          .map((p) => cv.Point(
                (p.x * inverseScale).round(),
                (p.y * inverseScale).round(),
              ))
          .toList();

      final ordered = _orderCorners(scaledPoints);

      // Original-frame dimensions after rotation, for UI normalisation.
      final int originalProcessedW = (processedW / scale).round();
      final int originalProcessedH = (processedH / scale).round();

      return {
        'corners': ordered.map((p) => {'x': p.x.toDouble(), 'y': p.y.toDouble()}).toList(),
        'isPerfect': isPerfect,
        'processedWidth': originalProcessedW,
        'processedHeight': originalProcessedH,
        // Full-resolution rotated Mat — ownership transferred to caller.
        'rotatedMat': rotateCode != null
            ? cv.rotate(input, rotateCode)
            : input.clone(),
      };
    } catch (error) {
      if (PcdParams.logProcessingTime) {
        debugPrint('[EdgeDetection] Error: $error');
      }
      return {'corners': [], 'isPerfect': false};
    } finally {
      contours?.dispose();
      closingKernel?.dispose();
      closed?.dispose();
      edges?.dispose();
      blurred?.dispose();
      gray?.dispose();
      rotatedSmall?.dispose();
      smallMat?.dispose();
      // rotatedMat (full-res) is NOT disposed here; ownership belongs to caller.
    }
  }

  /// Profile-aware corner detection used by the **capture (hi-res) path**
  /// (e.g. [DocumentPipeline]). The realtime stream path uses the optimised
  /// [findDocumentCorners] above; this variant honours per-document tuning
  /// (Canny thresholds, Gaussian kernel, min-area ratio) coming from the
  /// [PcdProfile] selected by the user on CameraPlanScreen.
  ///
  /// Returns ordered TL-TR-BR-BL points in the **input image** coordinate
  /// space, or an empty list if no acceptable quadrilateral is found.
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
      return _orderCornersByExtremes(points);
    } finally {
      bestApprox?.dispose();
      hierarchy?.dispose();
      contours?.dispose();
      edges?.dispose();
      blurred?.dispose();
      gray?.dispose();
    }
  }

  /// Orders four corner points as [top-left, top-right, bottom-right, bottom-left]
  /// using the sum-and-difference method to avoid hourglass artefacts.
  static List<cv.Point> _orderCorners(List<cv.Point> pts) {
    if (pts.length != 4) return pts;

    // TL has the smallest x+y sum; BR has the largest.
    pts.sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final tl = pts.first;
    final br = pts.last;

    // Of the remaining two, TR has the smallest y-x difference; BL the largest.
    final remaining = [pts[1], pts[2]];
    remaining.sort((a, b) => (a.y - a.x).compareTo(b.y - b.x));
    final tr = remaining.first;
    final bl = remaining.last;

    return [tl, tr, br, bl];
  }

  /// Alternate ordering used by the profile-aware path: split by x-extreme
  /// then by y. Equivalent for well-formed quads, slightly more robust to
  /// nearly-axis-aligned documents.
  static List<cv.Point> _orderCornersByExtremes(List<cv.Point> pts) {
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

  static cv.Mat _toGrayscale(cv.Mat input) {
    try {
      if (input.channels == 1) return input.clone();
      return cv.cvtColor(input, cv.COLOR_BGR2GRAY);
    } catch (_) {
      return cv.Mat.empty();
    }
  }

  /// Applies a bilateral filter for edge-preserving noise reduction.
  ///
  /// Preferred over Gaussian blur because it smooths intra-region noise while
  /// keeping sharp intensity gradients at the document boundary intact.
  static cv.Mat _applyBilateralFilter(cv.Mat gray) {
    try {
      return cv.bilateralFilter(gray, _bilateralD, _bilateralSigmaColor, _bilateralSigmaSpace);
    } catch (_) {
      return cv.Mat.empty();
    }
  }
}
