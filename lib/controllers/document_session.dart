// lib/controllers/document_session.dart
//
// State sesi dokumen multi-halaman (ala CamScanner). Setiap halaman adalah
// satu [ScanArtifact] hasil pipeline PCD/ML Kit. Controller ini menampung
// daftar halaman, halaman aktif, dan operasi tambah/hapus/reorder/replace.
//
// Dipakai oleh ScanResultScreen sebagai editor sebelum disimpan ke Hive
// atau diekspor ke PDF.

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/scan_artifact.dart';

class DocumentSession extends ChangeNotifier {
  DocumentSession(ScanArtifact first) : _pages = [first];

  final List<ScanArtifact> _pages;
  int _activeIndex = 0;

  List<ScanArtifact> get pages => List.unmodifiable(_pages);
  int get activeIndex => _activeIndex;
  ScanArtifact get active => _pages[_activeIndex];
  int get pageCount => _pages.length;
  bool get isMultiPage => _pages.length > 1;

  /// Path JPG enhanced semua halaman (untuk export PDF / simpan).
  List<String> get enhancedPaths =>
      _pages.map((p) => p.enhancedPath).toList(growable: false);

  void setActive(int index) {
    if (index < 0 || index >= _pages.length || index == _activeIndex) return;
    _activeIndex = index;
    notifyListeners();
  }

  /// Tambah halaman baru di akhir & jadikan aktif.
  void addPage(ScanArtifact artifact) {
    _pages.add(artifact);
    _activeIndex = _pages.length - 1;
    notifyListeners();
  }

  /// Ganti artifact pada halaman aktif (mis. setelah switch enhancement mode).
  void replaceActive(ScanArtifact artifact) {
    _pages[_activeIndex] = artifact;
    notifyListeners();
  }

  /// Ganti artifact pada [index] (mis. setelah foto ulang halaman itu).
  void replaceAt(int index, ScanArtifact artifact) {
    if (index < 0 || index >= _pages.length) return;
    _pages[index] = artifact;
    notifyListeners();
  }

  /// Hapus halaman pada [index]. Tidak boleh menghapus halaman terakhir
  /// (dokumen minimal punya 1 halaman). Best-effort menghapus file enhanced.
  bool removeAt(int index) {
    if (_pages.length <= 1) return false;
    if (index < 0 || index >= _pages.length) return false;
    final removed = _pages.removeAt(index);
    _cleanupFile(removed.enhancedPath);
    if (_activeIndex >= _pages.length) {
      _activeIndex = _pages.length - 1;
    } else if (index < _activeIndex) {
      _activeIndex -= 1;
    }
    notifyListeners();
    return true;
  }

  /// Pindahkan halaman dari [oldIndex] ke [newIndex] (untuk drag-reorder).
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _pages.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target >= _pages.length) target = _pages.length - 1;
    if (target == oldIndex) return;

    final activeArtifact = active;
    final moved = _pages.removeAt(oldIndex);
    _pages.insert(target, moved);
    _activeIndex = _pages.indexOf(activeArtifact);
    notifyListeners();
  }

  void _cleanupFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // best-effort
    }
  }
}
