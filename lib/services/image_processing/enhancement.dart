// lib/services/image_processing/enhancement.dart
//
// Empat mode enhancement, semua PCD murni (tidak ada ML).
//
//   bw        : klasik scan hitam-putih (paling tinggi kontras teks)
//               shadow removal → adaptive threshold → morph close 2x2
//   grayscale : grayscale soft (cocok untuk dokumen dengan diagram tipis)
//               shadow removal → CLAHE → bilateral filter
//   color     : warna dengan kontras lokal lebih tinggi (untuk dokumen warna)
//               CLAHE pada channel L (LAB) → bilateral filter → unsharp mask
//   magic     : seperti color tapi dengan boost saturasi & gamma untuk efek
//               "lifted page" ala CamScanner Magic Color
//
// Setiap function menerima [cv.Mat] BGR (atau grayscale untuk bw),
// return [cv.Mat] hasil siap di-encode JPG. Caller bertanggung jawab
// memanggil .dispose() pada hasilnya.
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../config/pcd_params.dart';
import 'shadow_removal.dart';

enum EnhancementMode { bw, grayscale, color, magic }

extension EnhancementModeLabel on EnhancementMode {
  String get label {
    switch (this) {
      case EnhancementMode.bw:
        return 'B&W';
      case EnhancementMode.grayscale:
        return 'Grayscale';
      case EnhancementMode.color:
        return 'Color';
      case EnhancementMode.magic:
        return 'Magic';
    }
  }
}

class EnhancementService {
  /// Entry tunggal: pilih sesuai [mode].
  static cv.Mat enhance(
    cv.Mat src,
    EnhancementMode mode, {
    required PcdProfile profile,
  }) {
    switch (mode) {
      case EnhancementMode.bw:
        return enhanceBlackWhite(src, profile: profile);
      case EnhancementMode.grayscale:
        return enhanceGrayscale(src, profile: profile);
      case EnhancementMode.color:
        return enhanceColor(src, profile: profile);
      case EnhancementMode.magic:
        return enhanceMagic(src, profile: profile);
    }
  }

  /// Backward-compat alias dengan signature lama (Phase 1).
  /// Default ke mode BW menggunakan profile auto.
  static cv.Mat enhanceDocument(cv.Mat input) {
    return enhanceBlackWhite(input, profile: PcdParams.auto);
  }

  // ---------------------- BW (resep "menebalkan teks") ----------------------

  static cv.Mat enhanceBlackWhite(
    cv.Mat src, {
    required PcdProfile profile,
  }) {
    if (src.isEmpty) return src.clone();

    cv.Mat? gray;
    cv.Mat? shadowless;
    cv.Mat? binary;
    cv.Mat? closeKernel;
    cv.Mat? closed;

    try {
      gray = src.channels == 3
          ? cv.cvtColor(src, cv.COLOR_BGR2GRAY)
          : src.clone();

      // Tahap 1: hapus iluminasi tidak rata.
      shadowless = ShadowRemovalService.removeShadowsGray(
        gray,
        kernelSize: profile.shadowKernelSize,
      );

      // Tahap 2: adaptive threshold Gaussian → binarisasi tahan shadow lokal.
      // THRESH_BINARY supaya teks gelap → 0, latar terang → 255 (putih).
      final block = profile.adaptiveBlockSize | 1; // odd
      binary = cv.adaptiveThreshold(
        shadowless,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY,
        block,
        profile.adaptiveC,
      );

      // Tahap 3: morphological closing kecil untuk menyambungkan stroke huruf
      // yang patah & "menebalkan" teks tipis.
      final kSize = profile.morphCloseKernel.clamp(1, 5);
      closeKernel = cv.getStructuringElement(cv.MORPH_RECT, (kSize, kSize));
      closed = cv.morphologyEx(binary, cv.MORPH_CLOSE, closeKernel);

      return closed.clone(); // kasih hasil "milik kita" yang aman di-dispose
    } finally {
      gray?.dispose();
      shadowless?.dispose();
      binary?.dispose();
      closeKernel?.dispose();
      closed?.dispose();
    }
  }

  // ---------------------- Grayscale (soft) ----------------------

  static cv.Mat enhanceGrayscale(
    cv.Mat src, {
    required PcdProfile profile,
  }) {
    if (src.isEmpty) return src.clone();

    cv.Mat? gray;
    cv.Mat? shadowless;
    cv.CLAHE? clahe;
    cv.Mat? equalized;
    cv.Mat? smoothed;

    try {
      gray = src.channels == 3
          ? cv.cvtColor(src, cv.COLOR_BGR2GRAY)
          : src.clone();
      shadowless = ShadowRemovalService.removeShadowsGray(
        gray,
        kernelSize: profile.shadowKernelSize,
      );

      clahe = cv.createCLAHE(
        clipLimit: profile.claheClipLimit,
        tileGridSize: (profile.claheTileGrid, profile.claheTileGrid),
      );
      equalized = clahe.apply(shadowless);

      // Bilateral filter: smoothing tapi pertahankan tepi huruf.
      smoothed = cv.bilateralFilter(equalized, 7, 60, 60);

      return smoothed.clone();
    } finally {
      gray?.dispose();
      shadowless?.dispose();
      clahe?.dispose();
      equalized?.dispose();
      smoothed?.dispose();
    }
  }

  // ---------------------- Color ----------------------

  static cv.Mat enhanceColor(
    cv.Mat src, {
    required PcdProfile profile,
  }) {
    if (src.isEmpty) return src.clone();

    if (src.channels == 1) {
      // Tidak bisa melakukan color enhancement dari grayscale.
      // Fallback ke grayscale enhancement.
      return enhanceGrayscale(src, profile: profile);
    }

    cv.Mat? lab;
    cv.VecMat? labChannels;
    cv.Mat? lEnhanced;
    cv.VecMat? mergedChannels;
    cv.Mat? labMerged;
    cv.Mat? bgr;
    cv.Mat? smoothed;
    cv.Mat? sharpened;
    cv.Mat? blurred;
    cv.CLAHE? clahe;

    try {
      // CLAHE pada channel L (luminance) di colorspace LAB:
      // tidak menggeser hue/saturation, hanya kontras lokal.
      lab = cv.cvtColor(src, cv.COLOR_BGR2Lab);
      labChannels = cv.split(lab);

      clahe = cv.createCLAHE(
        // Clip limit moderat — cukup untuk angkat kontras lokal pada catatan
        // tanpa over-sharpen artefak. Range 1.8–2.2 adalah sweet spot
        // untuk dokumen kertas dengan pencahayaan campuran.
        clipLimit: profile.claheClipLimit.clamp(1.8, 2.2),
        tileGridSize: (profile.claheTileGrid, profile.claheTileGrid),
      );
      lEnhanced = clahe.apply(labChannels[0]);

      mergedChannels = cv.VecMat.fromList([
        lEnhanced,
        labChannels[1],
        labChannels[2],
      ]);
      labMerged = cv.merge(mergedChannels);
      bgr = cv.cvtColor(labMerged, cv.COLOR_Lab2BGR);

      // Bilateral filter: kurangi noise tanpa kabur tepi.
      smoothed = cv.bilateralFilter(bgr, 7, 50, 50);

      // Unsharp mask: sharpened = 1.4*src - 0.4*blur
      // Cukup berasa "lifted" tanpa sampai bikin halo / over-sharpen.
      blurred = cv.gaussianBlur(smoothed, (5, 5), 1.0);
      sharpened = cv.addWeighted(smoothed, 1.4, blurred, -0.4, 0);

      return sharpened.clone();
    } finally {
      lab?.dispose();
      labChannels?.dispose();
      lEnhanced?.dispose();
      mergedChannels?.dispose();
      labMerged?.dispose();
      bgr?.dispose();
      smoothed?.dispose();
      blurred?.dispose();
      sharpened?.dispose();
      clahe?.dispose();
    }
  }

  // ---------------------- Magic ----------------------
  // Color + boost saturasi + gamma ringan → dokumen kelihatan "lifted".

  static cv.Mat enhanceMagic(
    cv.Mat src, {
    required PcdProfile profile,
  }) {
    if (src.isEmpty) return src.clone();

    if (src.channels == 1) {
      return enhanceGrayscale(src, profile: profile);
    }

    cv.Mat? colorEnhanced;
    cv.Mat? hsv;
    cv.VecMat? hsvChannels;
    cv.Mat? sBoosted;
    cv.VecMat? merged;
    cv.Mat? hsvMerged;
    cv.Mat? bgrFinal;

    try {
      // Mulai dari Color enhancement (CLAHE L + bilateral + unsharp).
      colorEnhanced = enhanceColor(src, profile: profile);

      // Boost saturasi 1.15× di HSV.
      hsv = cv.cvtColor(colorEnhanced, cv.COLOR_BGR2HSV);
      hsvChannels = cv.split(hsv);
      // S-channel × 1.15, clip ke [0, 255]. convertScaleAbs aman untuk uint8.
      sBoosted = cv.convertScaleAbs(hsvChannels[1], alpha: 1.15, beta: 0);

      merged = cv.VecMat.fromList([
        hsvChannels[0],
        sBoosted,
        hsvChannels[2],
      ]);
      hsvMerged = cv.merge(merged);
      bgrFinal = cv.cvtColor(hsvMerged, cv.COLOR_HSV2BGR);

      return bgrFinal.clone();
    } finally {
      colorEnhanced?.dispose();
      hsv?.dispose();
      hsvChannels?.dispose();
      sBoosted?.dispose();
      merged?.dispose();
      hsvMerged?.dispose();
      bgrFinal?.dispose();
    }
  }
}
