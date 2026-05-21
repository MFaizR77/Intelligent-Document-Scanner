// lib/config/pcd_params.dart
//
// Profil parameter PCD per-mode dokumen.
//
// Tujuan: parameter Canny / contour / CLAHE / adaptive threshold tidak
// hardcoded global, melainkan disesuaikan dengan jenis dokumen yang dipilih
// user pada CameraPlanScreen.
//
// Setiap algoritma di pipeline mengambil nilai dari [PcdProfile] yang
// dipilih, supaya tuning bisa dilakukan tanpa rebuild logic.

/// Mode dokumen yang dikenal aplikasi.
/// Nilai string-nya cocok dengan label di CameraPlanScreen / ScannerControls.
enum DocumentPlan { auto, a4, book, idCard }

DocumentPlan documentPlanFromLabel(String label) {
  switch (label.toLowerCase()) {
    case 'a4':
      return DocumentPlan.a4;
    case 'buku':
    case 'book':
      return DocumentPlan.book;
    case 'ktp':
    case 'id':
    case 'id card':
      return DocumentPlan.idCard;
    case 'auto':
    default:
      return DocumentPlan.auto;
  }
}

/// Profile parameter untuk satu jenis dokumen.
class PcdProfile {
  const PcdProfile({
    required this.label,
    required this.cannyThreshold1,
    required this.cannyThreshold2,
    required this.minContourAreaRatio,
    required this.gaussianKernel,
    required this.gaussianSigma,
    required this.claheClipLimit,
    required this.claheTileGrid,
    required this.adaptiveBlockSize,
    required this.adaptiveC,
    required this.shadowKernelSize,
    required this.morphCloseKernel,
    required this.targetAspectRatio,
  });

  final String label;

  // Canny thresholds.
  final double cannyThreshold1;
  final double cannyThreshold2;

  /// Luas minimum kontur sebagai rasio luas gambar (0..1).
  /// Lebih ketat untuk A4 (dokumen biasanya besar memenuhi frame),
  /// lebih longgar untuk KTP (dokumen kecil di tengah).
  final double minContourAreaRatio;

  final int gaussianKernel; // ganjil
  final double gaussianSigma;

  // CLAHE.
  final double claheClipLimit;
  final int claheTileGrid;

  // Adaptive threshold.
  final int adaptiveBlockSize; // ganjil
  final double adaptiveC;

  /// Ukuran kernel untuk shadow removal (morph dilate + median blur).
  final int shadowKernelSize; // ganjil

  /// Kernel untuk morphological closing setelah binarisasi.
  /// Ini yang "menebalkan" stroke huruf agar OCR lebih mudah.
  final int morphCloseKernel;

  /// Aspek rasio target (w/h). Dipakai sebagai hint kalau kontur
  /// tidak ditemukan: kita bisa propose default crop.
  final double targetAspectRatio;
}

class PcdParams {
  PcdParams._();

  static const PcdProfile auto = PcdProfile(
    label: 'Auto',
    cannyThreshold1: 50,
    cannyThreshold2: 150,
    minContourAreaRatio: 0.08,
    gaussianKernel: 5,
    gaussianSigma: 1.5,
    claheClipLimit: 2.0,
    claheTileGrid: 8,
    adaptiveBlockSize: 25,
    adaptiveC: 12,
    shadowKernelSize: 21,
    morphCloseKernel: 2,
    targetAspectRatio: 1 / 1.4142, // ≈ A4
  );

  static const PcdProfile a4 = PcdProfile(
    label: 'A4',
    cannyThreshold1: 60,
    cannyThreshold2: 170,
    minContourAreaRatio: 0.18,
    gaussianKernel: 5,
    gaussianSigma: 1.4,
    claheClipLimit: 2.0,
    claheTileGrid: 8,
    adaptiveBlockSize: 25,
    adaptiveC: 12,
    shadowKernelSize: 23,
    morphCloseKernel: 2,
    targetAspectRatio: 1 / 1.4142,
  );

  static const PcdProfile book = PcdProfile(
    label: 'Buku',
    cannyThreshold1: 45,
    cannyThreshold2: 140,
    minContourAreaRatio: 0.12,
    gaussianKernel: 5,
    gaussianSigma: 1.6,
    claheClipLimit: 2.5,
    claheTileGrid: 8,
    adaptiveBlockSize: 31,
    adaptiveC: 14,
    shadowKernelSize: 25,
    morphCloseKernel: 2,
    targetAspectRatio: 1 / 1.5,
  );

  static const PcdProfile idCard = PcdProfile(
    label: 'KTP',
    cannyThreshold1: 70,
    cannyThreshold2: 200,
    minContourAreaRatio: 0.05,
    gaussianKernel: 3,
    gaussianSigma: 1.0,
    claheClipLimit: 1.5,
    claheTileGrid: 8,
    adaptiveBlockSize: 19,
    adaptiveC: 10,
    shadowKernelSize: 15,
    morphCloseKernel: 1,
    targetAspectRatio: 85.6 / 53.98, // ISO/IEC 7810 ID-1
  );

  static PcdProfile profileFor(DocumentPlan plan) {
    switch (plan) {
      case DocumentPlan.auto:
        return auto;
      case DocumentPlan.a4:
        return a4;
      case DocumentPlan.book:
        return book;
      case DocumentPlan.idCard:
        return idCard;
    }
  }

  static PcdProfile profileForLabel(String label) =>
      profileFor(documentPlanFromLabel(label));

  // Auto-capture parameters.
  static const int autoCaptureStableMs = 900;
  static const double autoCaptureAreaTolerance = 0.05;
  static const double blurAcceptanceThreshold = 80.0;

  // Debug options.
  static bool enableDebugOverlay = true;
  static bool logProcessingTime = true;
}
