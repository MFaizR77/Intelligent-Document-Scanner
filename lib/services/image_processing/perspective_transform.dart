// lib/services/image_processing/perspective_transform.dart
import 'dart:math' as math;

import 'package:opencv_dart/opencv_dart.dart' as cv;

class PerspectiveTransformService {
  static cv.Mat applyPerspectiveTransform(cv.Mat src, List<cv.Point> corners) {
    if (corners.length != 4) return src.clone();

    final maxWidth = math
        .max(
          _distance(corners[0], corners[1]),
          _distance(corners[3], corners[2]),
        )
        .round();
    final maxHeight = math
        .max(
          _distance(corners[0], corners[3]),
          _distance(corners[1], corners[2]),
        )
        .round();

    if (maxWidth <= 0 || maxHeight <= 0) return src.clone();

    final dstPts = <cv.Point>[
      cv.Point(0, 0),
      cv.Point(maxWidth - 1, 0),
      cv.Point(maxWidth - 1, maxHeight - 1),
      cv.Point(0, maxHeight - 1),
    ];

    final srcVec = cv.VecPoint.fromList(corners);
    final dstVec = cv.VecPoint.fromList(dstPts);
    cv.Mat? homography;

    try {
      homography = cv.getPerspectiveTransform(srcVec, dstVec);

      return cv.warpPerspective(src, homography, (maxWidth, maxHeight));
    } finally {
      homography?.dispose();
      srcVec.dispose();
      dstVec.dispose();
      for (final point in dstPts) {
        point.dispose();
      }
    }
  }

  static double _distance(cv.Point a, cv.Point b) {
    final dx = (a.x - b.x).toDouble();
    final dy = (a.y - b.y).toDouble();
    return math.sqrt((dx * dx) + (dy * dy));
  }
}
