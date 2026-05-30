// lib/models/document_page.dart
//
// Representasi satu halaman dokumen yang dapat diolah ulang (image processing).
// Membawa metadata yang dibutuhkan untuk menjalankan kembali pipeline PCD
// (ganti mode enhancement) secara lossless dari gambar RAW.

import 'dart:ui';

import 'scan_artifact.dart';
import 'scan_engine.dart';

class DocumentPage {
  DocumentPage({
    required this.enhancedPath,
    required this.originalPath,
    required this.corners,
    required this.engine,
    required this.mode,
  });

  /// JPG hasil enhance (yang ditampilkan & masuk PDF).
  String enhancedPath;

  /// JPG mentah (sumber untuk rerun pipeline). Bisa sama dengan [enhancedPath]
  /// untuk data lama yang tidak menyimpan raw.
  final String originalPath;

  /// 4 sudut dalam koordinat RAW (TL-TR-BR-BL). Kosong = full-frame.
  final List<Offset> corners;

  final ScanEngine engine;

  /// Label mode enhancement aktif (Color/B&W/Grayscale/Magic).
  String mode;

  factory DocumentPage.fromArtifact(ScanArtifact a) => DocumentPage(
        enhancedPath: a.enhancedPath,
        originalPath: a.originalPath,
        corners: a.cornersImage,
        engine: a.engine,
        mode: a.enhancementMode,
      );

  /// Encode corners ke CSV "x1,y1,...,x4,y4" untuk disimpan di Hive.
  String get cornersCsv => corners
      .expand((o) => [o.dx, o.dy])
      .map((v) => v.toStringAsFixed(2))
      .join(',');

  static List<Offset> cornersFromCsv(String csv) {
    if (csv.trim().isEmpty) return const [];
    final parts = csv.split(',');
    if (parts.length < 8) return const [];
    final nums = parts.map((s) => double.tryParse(s) ?? 0).toList();
    return [
      Offset(nums[0], nums[1]),
      Offset(nums[2], nums[3]),
      Offset(nums[4], nums[5]),
      Offset(nums[6], nums[7]),
    ];
  }
}
