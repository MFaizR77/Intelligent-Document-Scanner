// lib/services/image_processing/perspective_transform.dart
import 'package:opencv_dart/opencv_dart.dart' as cv;

class PerspectiveTransformService {
  static cv.Mat applyPerspectiveTransform(cv.Mat src, List<cv.Point> corners) {
    if (corners.length != 4) return src.clone();

    // 1. Calculate dimensions of output image
    final widths = [
      (corners[0] - corners[1]).norm,
      (corners[3] - corners[2]).norm,
    ];
    final heights = [
      (corners[0] - corners[3]).norm,
      (corners[1] - corners[2]).norm,
    ];
    
    final maxWidth = widths.reduce((a, b) => a > b ? a : b).toInt();
    final maxHeight = heights.reduce((a, b) => a > b ? a : b).toInt();
    
    if (maxWidth == 0 || maxHeight == 0) return src.clone();

    // 2. Destination points (ordered rectangle)
    final dstPts = [
      cv.Point(0, 0),
      cv.Point(maxWidth - 1, 0),
      cv.Point(maxWidth - 1, maxHeight - 1),
      cv.Point(0, maxHeight - 1),
    ];
    
    // 3. Compute Homography Matrix
    final hMatrix = cv.Cv2.findHomography(
      corners,
      dstPts,
      cv.HomographyMethods.RANSAC,
      5.0,
    );
    
    // 4. Warp perspective
    final warped = cv.Cv2.warpPerspective(
      src,
      hMatrix,
      cv.Size(maxWidth, maxHeight),
    );
    
    // Cleanup
    hMatrix.dispose();
    
    return warped;
  }
}
