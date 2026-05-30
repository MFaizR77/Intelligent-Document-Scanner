// lib/services/storage/scan_repository.dart
//
// Wrapper Hive untuk koleksi `scan_results`.
// Menyatukan ScanArtifact (output pipeline) dengan ScanResult (model Hive),
// dan menyediakan stream listener untuk HistoryScreen.

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/scan_artifact.dart';
import '../../models/scan_result.dart';

class ScanRepository {
  ScanRepository._();
  static final ScanRepository instance = ScanRepository._();

  static const String _boxName = 'scan_results';

  Box<ScanResult> get _box => Hive.box<ScanResult>(_boxName);

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
