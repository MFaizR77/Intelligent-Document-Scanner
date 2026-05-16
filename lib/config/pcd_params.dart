// lib/config/pcd_params.dart
class PcdParams {
  // Canny Edge Detection
  static const double cannyThreshold1 = 50.0;
  static const double cannyThreshold2 = 150.0;

  // Contour Finding
  static const double minContourArea = 50000.0;

  // CLAHE Enhancement
  static const double claheClipLimit = 2.0;

  // Adaptive Thresholding
  static const int adaptiveBlockSize = 11;
  static const double adaptiveC = 2.0;

  // Blur Detection
  static const double blurThreshold = 100.0;

  // Display Output
  static const bool invertOutput = false;

  // Debug options
  static bool enableDebugOverlay = true;
  static bool logProcessingTime = true;
}
