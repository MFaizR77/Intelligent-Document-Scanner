// lib/services/image_processing/shadow_removal.dart
//
// Shadow removal berbasis division (illumination flattening).
//
// Model fisik: I(x,y) = R(x,y) · L(x,y)
//   I = pixel terobservasi
//   R = reflectance dokumen (yang kita inginkan)
//   L = iluminasi (bayangan / pencahayaan tidak rata)
//
// Estimasi L via morphological dilation + median blur menghasilkan
// "background plate" yang bebas teks. Membagi I/L lalu skala 255 menormalisasi
// pencahayaan sehingga bayangan hilang dan latar menjadi rata.
//
// Catatan akademis: ini masuk kategori PCD klasik — kombinasi morfologi
// matematis dan operasi titik (per-pixel division), tidak ada training.
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ShadowRemovalService {
  /// Buang bayangan/iluminasi tidak rata pada citra grayscale.
  ///
  /// [src] harus single-channel (CV_8UC1). Output juga single-channel.
  /// [kernelSize] menentukan seberapa besar struktur teks; kernel terlalu
  /// kecil akan ikut menghapus huruf, terlalu besar akan miss tepi-tepi
  /// pencahayaan halus. Default 21 cocok untuk dokumen A4 1080p.
  static cv.Mat removeShadowsGray(cv.Mat src, {int kernelSize = 21}) {
    if (src.isEmpty) return src.clone();
    final ks = kernelSize | 1; // ensure odd

    cv.Mat? kernel;
    cv.Mat? dilated;
    cv.Mat? bg;
    cv.Mat? bgFloat;
    cv.Mat? srcFloat;
    cv.Mat? divided;
    cv.Mat? result;

    try {
      kernel = cv.getStructuringElement(cv.MORPH_RECT, (ks, ks));
      // Dilate menghasilkan estimasi background (teks "tertelan" oleh dilasi).
      dilated = cv.dilate(src, kernel);
      // Median blur menghaluskan estimate, menghilangkan sisa-sisa edge teks.
      bg = cv.medianBlur(dilated, ks);

      // Konversi ke float supaya division presisi (uint8 division akan clip).
      srcFloat = src.convertTo(cv.MatType.CV_32FC1);
      bgFloat = bg.convertTo(cv.MatType.CV_32FC1);

      // norm = src / bg * 255  → membatalkan modulasi multiplikatif iluminasi.
      divided = cv.divide(srcFloat, bgFloat, scale: 255);

      // Konversi balik ke 8-bit, clipping ke [0, 255].
      result = divided.convertTo(cv.MatType.CV_8UC1);
      return result;
    } finally {
      kernel?.dispose();
      dilated?.dispose();
      bg?.dispose();
      srcFloat?.dispose();
      bgFloat?.dispose();
      divided?.dispose();
      // result NOT disposed — ownership ditransfer ke caller.
    }
  }
}
