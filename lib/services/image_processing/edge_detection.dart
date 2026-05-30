import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../config/pcd_params.dart';

/// Detects the four corner landmarks of a document in a camera frame using
/// a pure OpenCV pipeline (no external ML models).
///
/// Pipeline (realtime path):
///   downscale → CLAHE → bilateralFilter → adaptiveCanny ∪ SobelOtsu
///   → MORPH_CLOSE → top-N contour scoring → ordered TL-TR-BR-BL corners.
///
/// Reference notes:
///   - Adaptive Canny via the sigma method (Adrian Rosebrock, PyImageSearch)
///     replaces hard-coded thresholds that fail under uneven lighting.
///   - Dual edge map (Canny ∪ Sobel-Otsu) recovers weak gradients on glossy
///     ID cards / wood surfaces — a classic-CV equivalent of the multi-cue
///     scoring described in Readdle ScannerPro's first iteration blog post.
///   - Multiple candidates are scored (aspect, interior angles, area) instead
///     of trusting only the single largest contour, which is the common
///     failure mode pointed out in scanbot.io/techblog.
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

  // Adaptive Canny via sigma method. lower = max(0, (1-σ)·median),
  // upper = min(255, (1+σ)·median). σ=0.33 is the de-facto standard from
  // Rosebrock's analysis; mean is used as a cheaper proxy for median which
  // OpenCV's high-level Dart binding does not expose directly.
  static const double _cannySigma = 0.33;
  static const double _cannyLowerFloor = 10;
  static const double _cannyUpperCeil = 200;

  // Valid aspect-ratio range for documents we care about:
  //   A4 = 1.414, KTP/ID = 1.586, B5 = 1.41, Buku ~1.5, Receipt ≤ 2.0.
  // Loosened slightly from the previous 1.2-1.9 to give KTP and slightly
  // tilted A4 a safety margin.
  static const double _minAspectRatio = 1.15;
  static const double _maxAspectRatio = 2.10;

  // Maximum average per-corner deviation from 90° (degrees). Documents
  // photographed within ~30° of normal will fall well inside this budget;
  // skewed quadrilaterals (e.g. partially occluded or non-document objects)
  // exceed it and are rejected.
  static const double _maxAvgAngleDeviation = 25.0;

  // Number of top contours (by area) considered for scoring. ScannerPro v1
  // scored "all possible quadrilaterals"; for a 500-px realtime frame, 5 is
  // a safe ceiling that keeps the loop sub-millisecond.
  static const int _topCandidates = 5;

  // Adaptive epsilon factors for approxPolyDP. Trying multiple values is the
  // classic-CV remedy for the well-known "approxPolyDP returns 5 points"
  // failure when one corner is slightly noisy.
  static const List<double> _approxFactors = [0.02, 0.025, 0.03, 0.035, 0.04];

  /// Finds the four corner points of the largest document-like contour in [input].
  ///
  /// [rotateCode] is an optional `cv.ROTATE_*` constant. When provided, the
  /// downscaled frame is rotated **after** resize so that the rotation is
  /// performed on a small matrix (~500 px), keeping overhead near zero.
  ///
  /// Returns a map with:
  /// - `corners` — list of `{x, y}` maps in original-frame pixel coordinates.
  /// - `isPerfect` — true only when a convex quadrilateral with valid aspect
  ///   ratio AND interior angles near 90° is found.
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
    cv.CLAHE? clahe;
    cv.Mat? equalized;
    cv.Mat? blurred;
    cv.Mat? cannyEdges;
    cv.Mat? sobelX;
    cv.Mat? sobelY;
    cv.Mat? absX;
    cv.Mat? absY;
    cv.Mat? sobelMag;
    cv.Mat? sobelEdges;
    cv.Mat? combinedEdges;
    cv.Mat? closingKernel;
    cv.Mat? closed;
    cv.Contours? contours;

    try {
      // --- Downscale ---
      final double scale = input.cols > _maxProcessingWidth
          ? _maxProcessingWidth / input.cols
          : 1.0;
      final int smallW = (input.cols * scale).round();
      final int smallH = (input.rows * scale).round();
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

      // --- Local-contrast normalisation via CLAHE ---
      // CLAHE (Zuiderveld, 1994) replaces the previous global NORM_MINMAX
      // stretch. Local histogram equalisation handles uneven lighting and
      // shadows far better than a global minmax remap, which is the failure
      // mode highlighted by both Scanbot and Readdle ScannerPro write-ups.
      gray = _toGrayscale(processTarget);
      clahe = cv.createCLAHE(clipLimit: 2.0, tileGridSize: (8, 8));
      equalized = clahe.apply(gray);

      // --- Edge-preserving noise reduction ---
      blurred = cv.bilateralFilter(
        equalized,
        _bilateralD,
        _bilateralSigmaColor,
        _bilateralSigmaSpace,
      );

      // --- Adaptive Canny via sigma method ---
      // PyImageSearch's auto_canny: derive thresholds from image statistics
      // so the same code works on dark/bright/low-contrast frames without
      // re-tuning. Mean is used as a cheap median proxy.
      final meanScalar = cv.mean(blurred);
      final med = meanScalar.val1;
      final cannyLow = math
          .max(_cannyLowerFloor, (1.0 - _cannySigma) * med)
          .toDouble();
      final cannyHigh = math
          .min(_cannyUpperCeil, (1.0 + _cannySigma) * med)
          .toDouble();
      cannyEdges = cv.canny(blurred, cannyLow, cannyHigh);

      // --- Secondary edge channel: Sobel magnitude + Otsu threshold ---
      // Canny suppresses non-maximum gradients aggressively; weak edges on
      // matt or laminated surfaces (KTP, glossy book covers) are sometimes
      // missed entirely. Adding a Sobel-magnitude path with Otsu auto-thresh
      // recovers them. The two maps are unioned via bitwise OR.
      sobelX = cv.sobel(blurred, cv.MatType.CV_16S, 1, 0, ksize: 3);
      sobelY = cv.sobel(blurred, cv.MatType.CV_16S, 0, 1, ksize: 3);
      absX = cv.convertScaleAbs(sobelX);
      absY = cv.convertScaleAbs(sobelY);
      sobelMag = cv.addWeighted(absX, 0.5, absY, 0.5, 0);
      final thrTuple = cv.threshold(
        sobelMag,
        0,
        255,
        cv.THRESH_BINARY | cv.THRESH_OTSU,
      );
      sobelEdges = thrTuple.$2;

      combinedEdges = cv.bitwiseOR(cannyEdges, sobelEdges);

      // --- Morphological closing on the combined map ---
      closingKernel = cv.getStructuringElement(cv.MORPH_RECT, _closingKernelSize);
      closed = cv.morphologyEx(combinedEdges, cv.MORPH_CLOSE, closingKernel);

      // --- Contour detection ---
      final contourResult = cv.findContours(
        closed,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );
      contours = contourResult.$1;

      if (contours.isEmpty) return {'corners': [], 'isPerfect': false};

      // --- Top-N candidates by area ---
      // The "single largest contour" heuristic frequently picks shadow
      // boundaries, table edges, or partial documents. Scoring the top-5
      // and keeping the geometrically best one is robust against this.
      final imgArea = (processedW * processedH).toDouble();
      final minArea = imgArea * 0.05;
      final ranked = <_RankedContour>[];
      for (final contour in contours) {
        final area = cv.contourArea(contour);
        if (area > minArea) {
          ranked.add(_RankedContour(contour: contour, area: area));
        }
      }
      if (ranked.isEmpty) return {'corners': [], 'isPerfect': false};
      ranked.sort((a, b) => b.area.compareTo(a.area));

      _Candidate? best;
      for (var i = 0; i < math.min(_topCandidates, ranked.length); i++) {
        final entry = ranked[i];
        final cand = _evaluateCandidate(
          entry.contour,
          entry.area,
          processedW,
          processedH,
        );
        if (cand == null) continue;
        if (best == null || cand.score > best.score) {
          best = cand;
        }
      }

      if (best == null) return {'corners': [], 'isPerfect': false};

      // --- Scale coordinates back to original-frame resolution ---
      final inverseScale = 1.0 / scale;
      final scaledPoints = best.points
          .map((p) => cv.Point(
                (p.x * inverseScale).round(),
                (p.y * inverseScale).round(),
              ))
          .toList();
      final ordered = _orderCorners(scaledPoints);

      final originalProcessedW = (processedW / scale).round();
      final originalProcessedH = (processedH / scale).round();

      return {
        'corners': ordered.map((p) => {'x': p.x.toDouble(), 'y': p.y.toDouble()}).toList(),
        'isPerfect': best.isPerfect,
        'processedWidth': originalProcessedW,
        'processedHeight': originalProcessedH,
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
      closed?.dispose();
      closingKernel?.dispose();
      combinedEdges?.dispose();
      sobelEdges?.dispose();
      sobelMag?.dispose();
      absY?.dispose();
      absX?.dispose();
      sobelY?.dispose();
      sobelX?.dispose();
      cannyEdges?.dispose();
      blurred?.dispose();
      equalized?.dispose();
      clahe?.dispose();
      gray?.dispose();
      rotatedSmall?.dispose();
      smallMat?.dispose();
      // rotatedMat (full-res) is NOT disposed here; ownership belongs to caller.
    }
  }

  /// Profile-aware corner detection used by the **capture (hi-res) path**
  /// (e.g. [DocumentPipeline]). Same scoring strategy as the realtime path
  /// but parameter values come from [PcdProfile] so per-document tuning is
  /// honoured (e.g. KTP uses tighter Canny + smaller min-area).
  static List<cv.Point> findDocumentCornersWith(
    cv.Mat input,
    PcdProfile profile,
  ) {
    if (input.isEmpty) return [];

    cv.Mat? gray;
    cv.CLAHE? clahe;
    cv.Mat? equalized;
    cv.Mat? blurred;
    cv.Mat? cannyEdges;
    cv.Mat? sobelX;
    cv.Mat? sobelY;
    cv.Mat? absX;
    cv.Mat? absY;
    cv.Mat? sobelMag;
    cv.Mat? sobelEdges;
    cv.Mat? combinedEdges;
    cv.Mat? closingKernel;
    cv.Mat? closed;
    cv.Contours? contours;

    try {
      gray = input.channels == 3
          ? cv.cvtColor(input, cv.COLOR_BGR2GRAY)
          : input.clone();

      clahe = cv.createCLAHE(
        clipLimit: profile.claheClipLimit,
        tileGridSize: (profile.claheTileGrid, profile.claheTileGrid),
      );
      equalized = clahe.apply(gray);

      final ksize = profile.gaussianKernel | 1;
      blurred = cv.gaussianBlur(equalized, (ksize, ksize), profile.gaussianSigma);

      // Profile thresholds preserved as the primary Canny pass.
      cannyEdges = cv.canny(
        blurred,
        profile.cannyThreshold1,
        profile.cannyThreshold2,
      );

      // Sobel-Otsu rescue channel — same justification as realtime path.
      sobelX = cv.sobel(blurred, cv.MatType.CV_16S, 1, 0, ksize: 3);
      sobelY = cv.sobel(blurred, cv.MatType.CV_16S, 0, 1, ksize: 3);
      absX = cv.convertScaleAbs(sobelX);
      absY = cv.convertScaleAbs(sobelY);
      sobelMag = cv.addWeighted(absX, 0.5, absY, 0.5, 0);
      final thrTuple = cv.threshold(
        sobelMag,
        0,
        255,
        cv.THRESH_BINARY | cv.THRESH_OTSU,
      );
      sobelEdges = thrTuple.$2;

      combinedEdges = cv.bitwiseOR(cannyEdges, sobelEdges);

      closingKernel = cv.getStructuringElement(cv.MORPH_RECT, _closingKernelSize);
      closed = cv.morphologyEx(combinedEdges, cv.MORPH_CLOSE, closingKernel);

      final contourResult = cv.findContours(
        closed,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );
      contours = contourResult.$1;
      if (contours.isEmpty) return [];

      final imageArea = (input.cols * input.rows).toDouble();
      final minArea = profile.minContourAreaRatio * imageArea;

      final ranked = <_RankedContour>[];
      for (final contour in contours) {
        final area = cv.contourArea(contour);
        if (area > minArea) {
          ranked.add(_RankedContour(contour: contour, area: area));
        }
      }
      if (ranked.isEmpty) return [];
      ranked.sort((a, b) => b.area.compareTo(a.area));

      _Candidate? best;
      for (var i = 0; i < math.min(_topCandidates, ranked.length); i++) {
        final entry = ranked[i];
        final cand = _evaluateCandidate(
          entry.contour,
          entry.area,
          input.cols,
          input.rows,
        );
        if (cand == null) continue;
        if (best == null || cand.score > best.score) {
          best = cand;
        }
      }

      if (best == null) return [];
      return _orderCornersByExtremes(best.points);
    } finally {
      contours?.dispose();
      closed?.dispose();
      closingKernel?.dispose();
      combinedEdges?.dispose();
      sobelEdges?.dispose();
      sobelMag?.dispose();
      absY?.dispose();
      absX?.dispose();
      sobelY?.dispose();
      sobelX?.dispose();
      cannyEdges?.dispose();
      blurred?.dispose();
      equalized?.dispose();
      clahe?.dispose();
      gray?.dispose();
    }
  }

  /// Evaluates one contour as a quadrilateral candidate and returns a score
  /// in `[0, 1]`. Returns `null` if the candidate fails any geometric gate.
  ///
  /// Scoring weights (sum to 1.0):
  ///   - 0.40 angle: how close interior angles are to 90°
  ///   - 0.30 aspect: closeness to known document ratios (anchored at 1.41)
  ///   - 0.30 area: relative size in the frame
  static _Candidate? _evaluateCandidate(
    cv.Contour contour,
    double area,
    int frameW,
    int frameH,
  ) {
    final perimeter = cv.arcLength(contour, true);

    // Try multiple epsilons before falling back. This recovers the common
    // "approxPolyDP returned 5 points" case caused by one slightly noisy
    // corner.
    cv.VecPoint? quad;
    bool isPerfect = false;
    for (final factor in _approxFactors) {
      final approx = cv.approxPolyDP(contour, factor * perimeter, true);
      if (approx.length == 4) {
        quad?.dispose();
        quad = approx;
        isPerfect = true;
        break;
      }
      approx.dispose();
    }

    cv.VecPoint? boxVec;
    if (quad == null) {
      // Fallback: minAreaRect bounding quadrilateral. Marked as not-perfect
      // so the UI shows a tentative (red) overlay rather than triggering
      // auto-capture.
      final rect = cv.minAreaRect(contour);
      final boxMat = cv.boxPoints(rect);
      boxVec = cv.VecPoint.fromList(
        boxMat
            .toList()
            .map((p) => cv.Point(p.x.toInt(), p.y.toInt()))
            .toList(),
      );
      boxMat.dispose();
      quad = boxVec;
    }

    try {
      if (quad.length != 4) return null;

      // Convexity gate: real documents are always convex from a camera POV.
      if (!cv.isContourConvex(quad)) return null;

      // Aspect ratio gate via minAreaRect (orientation-agnostic).
      final rect = cv.minAreaRect(contour);
      final w = rect.size.width;
      final h = rect.size.height;
      if (w == 0 || h == 0) return null;
      final ratio = w > h ? w / h : h / w;
      if (ratio < _minAspectRatio || ratio > _maxAspectRatio) return null;

      final pts = quad.map((p) => cv.Point(p.x, p.y)).toList();
      final ordered = _orderCorners(pts);

      // Interior-angle gate.
      final angles = _interiorAngles(ordered);
      final avgDev = angles
              .map((a) => (a - 90.0).abs())
              .reduce((a, b) => a + b) /
          4.0;
      if (avgDev > _maxAvgAngleDeviation) return null;

      // --- Component scores in [0, 1] ---
      final angleScore = (1.0 - avgDev / 30.0).clamp(0.0, 1.0);
      final aspectScore =
          (1.0 - (ratio - 1.41).abs() / 0.6).clamp(0.0, 1.0);
      final areaScore =
          (area / (frameW * frameH)).clamp(0.0, 1.0);

      final score = angleScore * 0.40 + aspectScore * 0.30 + areaScore * 0.30;

      return _Candidate(points: ordered, isPerfect: isPerfect, score: score);
    } finally {
      quad.dispose();
    }
  }

  /// Returns the four interior angles (degrees) of an ordered quadrilateral.
  static List<double> _interiorAngles(List<cv.Point> pts) {
    final out = List<double>.filled(4, 0);
    for (var i = 0; i < 4; i++) {
      final prev = pts[(i + 3) % 4];
      final curr = pts[i];
      final next = pts[(i + 1) % 4];
      final v1x = (prev.x - curr.x).toDouble();
      final v1y = (prev.y - curr.y).toDouble();
      final v2x = (next.x - curr.x).toDouble();
      final v2y = (next.y - curr.y).toDouble();
      final n1 = math.sqrt(v1x * v1x + v1y * v1y);
      final n2 = math.sqrt(v2x * v2x + v2y * v2y);
      if (n1 == 0 || n2 == 0) {
        out[i] = 0;
        continue;
      }
      final cosA = ((v1x * v2x + v1y * v2y) / (n1 * n2)).clamp(-1.0, 1.0);
      out[i] = math.acos(cosA) * 180.0 / math.pi;
    }
    return out;
  }

  /// Orders four corner points as [top-left, top-right, bottom-right, bottom-left]
  /// using the sum-and-difference method to avoid hourglass artefacts.
  static List<cv.Point> _orderCorners(List<cv.Point> pts) {
    if (pts.length != 4) return pts;

    pts.sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final tl = pts.first;
    final br = pts.last;

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

    return [leftMost[0], rightMost[0], rightMost[1], leftMost[1]];
  }

  static cv.Mat _toGrayscale(cv.Mat input) {
    try {
      if (input.channels == 1) return input.clone();
      return cv.cvtColor(input, cv.COLOR_BGR2GRAY);
    } catch (_) {
      return cv.Mat.empty();
    }
  }
}

class _RankedContour {
  _RankedContour({required this.contour, required this.area});
  final cv.Contour contour;
  final double area;
}

class _Candidate {
  _Candidate({
    required this.points,
    required this.isPerfect,
    required this.score,
  });
  final List<cv.Point> points;
  final bool isPerfect;
  final double score;
}
