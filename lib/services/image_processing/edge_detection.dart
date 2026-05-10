// lib/services/image_processing/edge_detection.dart
import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../../config/pcd_params.dart';

class EdgeDetectionService {
  static List<cv.Point> findDocumentCorners(cv.Mat input) {
    if (input.isEmpty) return [];
    
    cv.Mat gray;
    if (input.channels == 3) {
      gray = cv.Cv2.cvtColor(input, cv.ColorConversionCodes.COLOR_BGR2GRAY);
    } else {
      gray = input.clone();
    }
    
    final blurred = cv.Cv2.GaussianBlur(gray, cv.Size(5, 5), 1.5);
    
    final edges = cv.Cv2.Canny(
      blurred,
      PcdParams.cannyThreshold1,
      PcdParams.cannyThreshold2,
    );
    
    final contours = cv.Cv2.findContours(
      edges,
      cv.RetrievalModes.RETR_EXTERNAL,
      cv.ContourApproximationModes.APPROX_SIMPLE,
    );
    
    cv.Contour? documentContour;
    double maxArea = PcdParams.minContourArea;
    
    for (final contour in contours) {
      final area = cv.Cv2.contourArea(contour);
      if (area > maxArea) {
        final epsilon = 0.02 * cv.Cv2.arcLength(contour, true);
        final approx = cv.Cv2.approxPolyDP(contour, epsilon, true);
        
        if (approx.length == 4) {
          maxArea = area;
          documentContour = approx;
        }
      }
    }
    
    List<cv.Point> result = [];
    if (documentContour != null) {
      result = _orderCorners(documentContour.toList());
    }
    
    // Cleanup
    gray.dispose();
    blurred.dispose();
    edges.dispose();
    for (final c in contours) c.dispose();
    
    return result;
  }

  static List<cv.Point> _orderCorners(List<cv.Point> pts) {
    if (pts.length != 4) return pts;
    
    // Sort logic to return [TL, TR, BR, BL]
    pts.sort((a, b) => a.x.compareTo(b.x));
    
    final leftMost = [pts[0], pts[1]];
    final rightMost = [pts[2], pts[3]];
    
    leftMost.sort((a, b) => a.y.compareTo(b.y));
    final tl = leftMost[0];
    final bl = leftMost[1];
    
    rightMost.sort((a, b) => a.y.compareTo(b.y));
    final tr = rightMost[0];
    final br = rightMost[1];
    
    return [tl, tr, br, bl];
  }
}
