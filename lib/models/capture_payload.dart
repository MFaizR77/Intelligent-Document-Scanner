// lib/models/capture_payload.dart
import 'dart:ui';

/// Data yang dilewatkan dari ScannerScreen → CropScreen → ProcessingScreen.
///
/// `rawImagePath` adalah JPG hi-res hasil `takePicture()` (atau gambar dari
/// galeri). Korner opsional disertakan kalau realtime detection sudah berhasil
/// menemukan dokumen — ini jadi titik awal untuk widget crop manual.
class CapturePayload {
  const CapturePayload({
    required this.rawImagePath,
    required this.documentPlan,
    this.suggestedCornersImage,
    this.imageWidth,
    this.imageHeight,
  });

  /// Path JPG full-color yang akan diolah pipeline.
  final String rawImagePath;

  /// Plan/mode dari camera plan screen ('Auto', 'A4', 'Buku', 'KTP').
  final String documentPlan;

  /// Saran 4 sudut dalam koordinat IMAGE (pixel), urutan TL-TR-BR-BL.
  /// Bisa null kalau tidak ada deteksi realtime sebelum capture.
  final List<Offset>? suggestedCornersImage;

  /// Dimensi gambar mentah, untuk konversi koordinat overlay→image.
  final int? imageWidth;
  final int? imageHeight;
}
