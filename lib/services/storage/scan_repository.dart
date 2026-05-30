// lib/services/storage/scan_repository.dart
//
// Wrapper Hive untuk koleksi `scan_results`.
// Menyatukan ScanArtifact (output pipeline) dengan ScanResult (model Hive),
// dan menyediakan stream listener untuk HistoryScreen.

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/document_page.dart';
import '../../models/scan_artifact.dart';
import '../../models/scan_result.dart';

class ScanRepository {
  ScanRepository._();
  static final ScanRepository instance = ScanRepository._();

  static const String _boxName = 'scan_results';

  Box<ScanResult> get _box => Hive.box<ScanResult>(_boxName);

  /// Simpan dokumen (multi-halaman) beserta metadata per-halaman supaya
  /// image processing (ganti mode enhancement) bisa di-rerun dari sumber raw.
  Future<ScanResult> savePages({
    required List<DocumentPage> pages,
    required String documentType,
    required double blurScore,
    String? title,
  }) async {
    final conf = (blurScore / 200).clamp(0.0, 1.0);
    final entry = _buildEntry(
      pages: pages,
      scanDate: DateTime.now(),
      documentType: documentType,
      confidenceScore: conf,
      title: title,
    );
    await _box.add(entry);
    return entry;
  }

  /// Update entry tersimpan dengan daftar [DocumentPage] baru + nama.
  Future<ScanResult> updatePages(
    ScanResult old, {
    required List<DocumentPage> pages,
    String? title,
  }) async {
    final entry = _buildEntry(
      pages: pages,
      scanDate: old.scanDate,
      documentType: old.documentType,
      confidenceScore: old.confidenceScore,
      title: (title != null && title.trim().isNotEmpty) ? title.trim() : old.title,
    );
    final key = old.key;
    if (key != null) {
      await _box.put(key, entry);
    } else {
      await _box.add(entry);
    }
    return entry;
  }

  ScanResult _buildEntry({
    required List<DocumentPage> pages,
    required DateTime scanDate,
    required String documentType,
    required double confidenceScore,
    String? title,
  }) {
    final enhanced = pages.map((p) => p.enhancedPath).toList();
    return ScanResult(
      imagePath: enhanced.first,
      scanDate: scanDate,
      documentType: documentType,
      confidenceScore: confidenceScore,
      title: (title != null && title.trim().isNotEmpty) ? title.trim() : null,
      pagePaths: enhanced,
      originalPaths: pages.map((p) => p.originalPath).toList(),
      pageCorners: pages.map((p) => p.cornersCsv).toList(),
      pageEngines: pages.map((p) => p.engine.name).toList(),
      pageModes: pages.map((p) => p.mode).toList(),
    );
  }

  /// Simpan hasil pipeline. Path yang disimpan adalah enhancedPath.
  /// [docType] biasanya diambil dari [ScanArtifact.documentPlanLabel].
  /// [title] nama dokumen yang diberi user (opsional).
  /// [pagePaths] daftar halaman untuk dokumen multi-halaman; bila null/kosong
  /// dokumen diperlakukan single-page memakai enhancedPath.
  Future<ScanResult> save(
    ScanArtifact artifact, {
    String? docType,
    String? title,
    List<String>? pagePaths,
  }) async {
    // Confidence proxy: blurScore yang di-clip ke [0..1] dengan saturasi 200.
    final conf = (artifact.blurScore / 200).clamp(0.0, 1.0);
    final pages = (pagePaths != null && pagePaths.isNotEmpty)
        ? pagePaths
        : <String>[artifact.enhancedPath];
    final entry = ScanResult(
      imagePath: pages.first,
      scanDate: DateTime.now(),
      documentType: docType ?? artifact.documentPlanLabel,
      confidenceScore: conf,
      title: (title != null && title.trim().isNotEmpty) ? title.trim() : null,
      pagePaths: pages,
    );
    await _box.add(entry);
    return entry;
  }

  /// Listenable untuk drive UI (mis. HistoryScreen).
  ValueListenable<Box<ScanResult>> listenable() => _box.listenable();

  /// Perbarui entry yang sudah tersimpan (nama dokumen / daftar halaman).
  /// Menyimpan kembali ke key Hive yang sama supaya posisi & identitas entry
  /// tetap. Mengembalikan entry baru hasil update.
  Future<ScanResult> update(
    ScanResult old, {
    String? title,
    List<String>? pagePaths,
  }) async {
    final pages = (pagePaths != null && pagePaths.isNotEmpty)
        ? pagePaths
        : old.pages;
    final entry = ScanResult(
      imagePath: pages.first,
      scanDate: old.scanDate,
      documentType: old.documentType,
      confidenceScore: old.confidenceScore,
      title: (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : old.title,
      pagePaths: pages,
      // Pertahankan metadata lama bila panjangnya cocok dengan jumlah halaman.
      originalPaths: (old.originalPaths != null &&
              old.originalPaths!.length == pages.length)
          ? old.originalPaths
          : null,
      pageCorners: (old.pageCorners != null &&
              old.pageCorners!.length == pages.length)
          ? old.pageCorners
          : null,
      pageEngines: (old.pageEngines != null &&
              old.pageEngines!.length == pages.length)
          ? old.pageEngines
          : null,
      pageModes:
          (old.pageModes != null && old.pageModes!.length == pages.length)
              ? old.pageModes
              : null,
    );
    final key = old.key;
    if (key != null) {
      await _box.put(key, entry);
    } else {
      await _box.add(entry);
    }
    return entry;
  }

  List<ScanResult> all() {
    final list = _box.values.toList();
    list.sort((a, b) => b.scanDate.compareTo(a.scanDate));
    return list;
  }

  Future<void> delete(ScanResult result) async {
    await result.delete();
  }

  /// Hapus seluruh entry riwayat. Mengembalikan jumlah yang terhapus.
  Future<int> deleteAll() async {
    final count = _box.length;
    await _box.clear();
    return count;
  }
}
