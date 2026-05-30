// lib/services/scanner/mlkit_document_scanner_service.dart
//
// Wrapper tipis di atas google_mlkit_document_scanner.
//
// ML Kit Document Scanner adalah UI flow full-screen yang disediakan Google
// Play Services: kita panggil → ML Kit ambil alih layar (kamera + UI scan
// sendiri) → mengembalikan path JPEG yang SUDAH ter-crop + deskew (warp) +
// auto-rotate. Tidak butuh izin kamera app dan tidak ada image stream, jadi
// jalur ini bebas dari masalah kebocoran kamera.
//
// Mode: SCANNER_MODE_BASE (ScannerMode.base) — hanya crop/rotate/perspektif,
// TANPA filter/grayscale/enhancement bawaan ML Kit. Ini penting supaya tahap
// enhancement PCD kita (shadow removal, CLAHE, adaptive threshold) tidak
// tabrakan dengan enhancement bawaan ML Kit.
//
// Catatan: API ini Android-only (masih Beta). Caller harus memastikan
// Platform.isAndroid sebelum memakai service ini.

import 'dart:io';

import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import '../storage/file_service.dart';

class MlkitScanException implements Exception {
  MlkitScanException(this.message);
  final String message;

  @override
  String toString() => 'MlkitScanException: $message';
}

class MlkitDocumentScannerService {
  MlkitDocumentScannerService._();

  /// True hanya pada Android (satu-satunya platform yang didukung ML Kit
  /// Document Scanner saat ini).
  static bool get isSupported => Platform.isAndroid;

  /// Jalankan UI scanner ML Kit (SCANNER_MODE_BASE), ambil halaman pertama,
  /// lalu salin ke direktori `scans/raw` aplikasi supaya path-nya stabil dan
  /// konsisten dengan jalur capture lain (kamera/galeri).
  ///
  /// Mengembalikan path JPG hasil scan (sudah ter-crop & lurus), atau `null`
  /// jika user membatalkan scan.
  ///
  /// Melempar [MlkitScanException] bila platform tidak didukung atau scanner
  /// gagal (mis. Google Play Services tidak tersedia di device).
  static Future<String?> scanToRawJpeg() async {
    if (!isSupported) {
      throw MlkitScanException(
        'ML Kit Document Scanner hanya tersedia di Android.',
      );
    }

    final options = DocumentScannerOptions(
      documentFormats: const {DocumentFormat.jpeg},
      mode: ScannerMode.base, // SCANNER_MODE_BASE: crop/rotate/perspektif saja.
      pageLimit: 1,
      isGalleryImport: true,
    );

    final scanner = DocumentScanner(options: options);
    try {
      final DocumentScanningResult result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      if (images.isEmpty) {
        // User menutup scanner tanpa menghasilkan halaman.
        return null;
      }

      final sourcePath = images.first;
      final dst = await FileService.newRawJpegPath();
      await File(sourcePath).copy(dst);
      return dst;
    } on MlkitScanException {
      rethrow;
    } catch (error) {
      // google_mlkit_document_scanner melempar PlatformException saat user
      // menekan back/cancel pada beberapa versi. Perlakukan pesan cancel
      // sebagai pembatalan (return null), selain itu lempar sebagai error.
      final msg = error.toString().toLowerCase();
      if (msg.contains('cancel')) {
        return null;
      }
      throw MlkitScanException('Gagal menjalankan ML Kit Scanner: $error');
    } finally {
      await scanner.close();
    }
  }
}
