// lib/models/scan_engine.dart
//
// Sumber/engine yang dipakai untuk meng-capture & memetakan dokumen sebelum
// masuk ke tahap enhancement PCD.
//
//   pcd   : scanner buatan sendiri (kamera realtime → Canny + contour →
//           homography/warp). Tahap geometri ditangani pipeline PCD.
//   mlkit : Google ML Kit Document Scanner (SCANNER_MODE_BASE). Deteksi tepi,
//           crop, dan koreksi perspektif dilakukan oleh ML Kit; pipeline PCD
//           cukup menjalankan tahap hilir (shadow removal + enhancement).

enum ScanEngine { pcd, mlkit }

extension ScanEngineLabel on ScanEngine {
  String get label {
    switch (this) {
      case ScanEngine.pcd:
        return 'PCD';
      case ScanEngine.mlkit:
        return 'ML Kit';
    }
  }

  /// Apakah tahap geometri (deteksi sudut + warp perspektif) pada
  /// [DocumentPipeline] harus dilewati. ML Kit sudah meluruskan dokumen,
  /// jadi pipeline tidak perlu mendeteksi & warp ulang.
  bool get skipGeometry => this == ScanEngine.mlkit;
}
