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
    cv.CLAHE? clahe;
    cv.Mat? equalized;
    cv.Mat? binary;
    cv.Mat? closeKernel;
    cv.Mat? closed;
    cv.Mat? blended;

    try {
      gray = src.channels == 3
          ? cv.cvtColor(src, cv.COLOR_BGR2GRAY)
          : src.clone();

      // Tahap 1: hapus iluminasi tidak rata.
      shadowless = ShadowRemovalService.removeShadowsGray(
        gray,
        kernelSize: profile.shadowKernelSize,
      );

      // Tahap 2: CLAHE moderat pada hasil shadow-removal supaya midtone
      // tidak hilang total saat di-blend dengan binary di tahap 4.
      clahe = cv.createCLAHE(
        clipLimit: profile.claheClipLimit.clamp(1.5, 2.0),
        tileGridSize: (profile.claheTileGrid, profile.claheTileGrid),
      );
      equalized = clahe.apply(shadowless);

      // Tahap 3: adaptive threshold Gaussian → binarisasi tahan shadow lokal.
      // THRESH_BINARY supaya teks gelap → 0, latar terang → 255 (putih).
      final block = profile.adaptiveBlockSize | 1; // odd
      binary = cv.adaptiveThreshold(
        equalized,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY,
        block,
        profile.adaptiveC,
      );

      // Tahap 4: morphological closing kecil untuk menyambungkan stroke huruf
      // yang patah & "menebalkan" teks tipis.
      final kSize = profile.morphCloseKernel.clamp(1, 5);
      closeKernel = cv.getStructuringElement(cv.MORPH_RECT, (kSize, kSize));
      closed = cv.morphologyEx(binary, cv.MORPH_CLOSE, closeKernel);

      // Tahap 5: blend binary (threshold keras) dengan grayscale yang sudah
      // di-CLAHE. Resep ini ala "Document" mode CamScanner — hitam-putih
      // yang tidak ekstrem: stroke teks tetap padat tapi midtone (pensil
      // tipis, gradasi kertas) tidak ikut hilang.
      //   final = 0.55 * binary + 0.45 * equalized
      blended = cv.addWeighted(closed, 0.55, equalized, 0.45, 0);

      return blended.clone();
    } finally {
      gray?.dispose();
      shadowless?.dispose();
      clahe?.dispose();
      equalized?.dispose();
      binary?.dispose();
      closeKernel?.dispose();
      closed?.dispose();
      blended?.dispose();
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
        // Clip limit naik sedikit dari sweet spot (1.8–2.2) supaya kontras
        // lokal lebih terangkat — gradasi pensil & tinta lebih kelihatan.
        clipLimit: profile.claheClipLimit.clamp(2.2, 2.6),
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
      smoothed = cv.bilateralFilter(bgr, 7, 55, 55);

      // Unsharp mask: sharpened = 1.5*src - 0.5*blur (sigma 1.0).
      // Lebih berasa dari 1.4/-0.4 sebelumnya, tapi belum sampai bikin halo
      // ekstrem seperti percobaan pertama yang 1.5/-0.5 dengan kernel besar.
      blurred = cv.gaussianBlur(smoothed, (5, 5), 1.0);
      sharpened = cv.addWeighted(smoothed, 1.5, blurred, -0.5, 0);

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
