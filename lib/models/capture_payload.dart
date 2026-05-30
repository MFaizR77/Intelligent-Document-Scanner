// lib/models/capture_payload.dart
import 'dart:ui';

import 'scan_engine.dart';

/// Data yang dilewatkan dari ScannerScreen → CropScreen → ProcessingScreen.
///
/// `rawImagePath` adalah JPG hi-res hasil `takePicture()` (atau gambar dari
/// galeri). Korner opsional disertakan kalau realtime detection sudah berhasil
/// menemukan dokumen — ini jadi titik awal untuk widget crop manual.
class CapturePayload {
  const CapturePayload({
    required this.rawImagePath,
    required this.documentPlan,
    this.engine = ScanEngine.pcd,
    this.suggestedCornersImage,
    this.imageWidth,
    this.imageHeight,
  });

  /// Path JPG full-color yang akan diolah pipeline.
  final String rawImagePath;

  /// Plan/mode dari camera plan screen ('Auto', 'A4', 'Buku', 'KTP').
  final String documentPlan;

  /// Engine yang dipakai untuk capture/deteksi. Menentukan apakah pipeline
  /// perlu menjalankan tahap geometri (deteksi sudut + warp) atau tidak.
  /// ML Kit sudah meluruskan dokumen, jadi tahap itu dilewati.
  final ScanEngine engine;

  /// Saran 4 sudut dalam koordinat IMAGE (pixel), urutan TL-TR-BR-BL.
  /// Bisa null kalau tidak ada deteksi realtime sebelum capture.
  final List<Offset>? suggestedCornersImage;

  /// Dimensi gambar mentah, untuk konversi koordinat overlay→image.
  final int? imageWidth;
  final int? imageHeight;
}
