// lib/services/storage/file_service.dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Wrapper sederhana di atas path_provider untuk menyimpan artefak scan
/// (gambar mentah hasil capture, gambar hasil pipeline, dan PDF export).
class FileService {
  FileService._();

  static const _uuid = Uuid();

  /// Direktori utama untuk semua hasil scan, di dalam app documents.
  /// Layout:
  ///   `<docs>/scans/raw/`        ← capture mentah dari kamera/galeri
  ///   `<docs>/scans/enhanced/`   ← hasil pipeline PCD (siap tampil/share/OCR)
  ///   `<docs>/scans/pdf/`        ← PDF export
  static Future<Directory> _ensureSubdir(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/scans/$name');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Generate path baru untuk file JPG mentah.
  static Future<String> newRawJpegPath() async {
    final dir = await _ensureSubdir('raw');
    return '${dir.path}/${_uuid.v4()}.jpg';
  }

  /// Generate path baru untuk file JPG hasil pipeline.
  static Future<String> newEnhancedJpegPath() async {
    final dir = await _ensureSubdir('enhanced');
    return '${dir.path}/${_uuid.v4()}.jpg';
  }

  /// Generate path baru untuk file PDF.
  static Future<String> newPdfPath({String? hint, String? exactName}) async {
    final dir = await _ensureSubdir('pdf');
    if (exactName != null && exactName.isNotEmpty) {
      String cleanName = exactName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (!cleanName.toLowerCase().endsWith('.pdf')) {
        cleanName += '.pdf';
      }
      return '${dir.path}/$cleanName';
    }
    final base = hint?.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_') ?? 'scan';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${base}_$stamp.pdf';
  }

  /// Hapus file kalau ada.
  static Future<void> deleteIfExists(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) {
        await f.delete();
      }
    } catch (_) {
      // Best-effort cleanup; abaikan error.
    }
  }
}
