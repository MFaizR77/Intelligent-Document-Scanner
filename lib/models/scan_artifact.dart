// lib/models/scan_artifact.dart
import 'dart:ui';

/// Hasil sekali jalan pipeline PCD (deteksi → warp → enhance).
/// Belum tersimpan ke Hive; itu tugas ScanRepository di M4.
class ScanArtifact {
  const ScanArtifact({
    required this.originalPath,
    required this.enhancedPath,
    required this.cornersImage,
    required this.documentPlanLabel,
    required this.enhancementMode,
    required this.blurScore,
    required this.totalDuration,
    required this.imageWidth,
    required this.imageHeight,
  });

  /// JPG mentah (sebelum warp & enhance).
  final String originalPath;

  /// JPG hasil pipeline (sudah diluruskan + enhanced).
  final String enhancedPath;

  /// 4 sudut yang dipakai pipeline, dalam koordinat IMAGE asli (pixel).
  /// Urutan TL-TR-BR-BL.
  final List<Offset> cornersImage;

  final String documentPlanLabel;
  final String enhancementMode;

  /// Variance Laplacian — proxy ketajaman. Lebih besar = lebih tajam.
  final double blurScore;

  /// Total wall-clock pipeline (dipakai di laporan akademis).
  final Duration totalDuration;

  final int imageWidth;
  final int imageHeight;
}
