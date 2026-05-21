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
  Future<ScanResult> save(ScanArtifact artifact, {String? docType}) async {
    // Confidence proxy: blurScore yang di-clip ke [0..1] dengan saturasi 200.
    final conf = (artifact.blurScore / 200).clamp(0.0, 1.0);
    final entry = ScanResult(
      imagePath: artifact.enhancedPath,
      scanDate: DateTime.now(),
      documentType: docType ?? artifact.documentPlanLabel,
      confidenceScore: conf,
    );
    await _box.add(entry);
    return entry;
  }

  /// Listenable untuk drive UI (mis. HistoryScreen).
  ValueListenable<Box<ScanResult>> listenable() => _box.listenable();

  List<ScanResult> all() {
    final list = _box.values.toList();
    list.sort((a, b) => b.scanDate.compareTo(a.scanDate));
    return list;
  }

  Future<void> delete(ScanResult result) async {
    await result.delete();
  }
}
