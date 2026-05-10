// lib/services/image_processing/enhancement.dart
import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../../config/pcd_params.dart';

class EnhancementService {
  static cv.Mat enhanceDocument(cv.Mat input) {
    if (input.isEmpty) return input.clone();

    // 1. Grayscale
    cv.Mat gray;
    if (input.channels == 3) {
      gray = cv.Cv2.cvtColor(input, cv.ColorConversionCodes.COLOR_BGR2GRAY);
    } else {
      gray = input.clone();
    }
    
    // 2. Denoise
    final denoised = cv.Cv2.fastNlMeansDenoising(gray, h: 10);
    
    // 3. CLAHE
    final clahe = cv.Cv2.createCLAHE(
      clipLimit: PcdParams.claheClipLimit,
      tileGridSize: cv.Size(8, 8),
    );
    final equalized = clahe.apply(denoised);
    
    // 4. Adaptive Thresholding
    final binary = cv.Cv2.adaptiveThreshold(
      equalized,
      255,
      cv.AdaptiveThresholdTypes.ADAPTIVE_THRESH_GAUSSIAN_C,
      cv.ThresholdTypes.THRESH_BINARY_INV,
      PcdParams.adaptiveBlockSize,
      PcdParams.adaptiveC,
    );
    
    // 5. Morphological cleanup
    final kernel = cv.Cv2.getStructuringElement(
      cv.MorphShapes.MORPH_RECT, 
      cv.Size(2, 2),
    );
    final opened = cv.Cv2.morphologyEx(
      binary, 
      cv.MorphTypes.MORPH_OPEN, 
      kernel,
    );
    
    // 6. Invert if necessary
    final result = PcdParams.invertOutput 
      ? cv.Cv2.bitwiseNot(opened) 
      : opened.clone();
    
    //  CRITICAL: Dispose ALL intermediate Mats
    if (gray != input) gray.dispose();
    denoised.dispose();
    equalized.dispose();
    binary.dispose();
    opened.dispose();
    kernel.dispose();
    clahe.dispose();
    
    return result;
  }
}
