// lib/controllers/auto_capture_controller.dart
//
// Memantau aliran deteksi dari ScannerController; ketika korner stabil
// (delta luas polygon kecil) selama [stableDuration], trigger capture.
//
// Stabilitas dihitung dari rasio luas polygon dibanding luas frame.
// Kalau detection state bukan 'ready' → countdown direset.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:tugasbesar_pcd/config/pcd_params.dart';
import 'package:tugasbesar_pcd/controllers/scanner_controller.dart';

class AutoCaptureController extends ChangeNotifier {
  AutoCaptureController({
    required this.scanner,
    required this.onTrigger,
    Duration? stableDuration,
    double? areaTolerance,
  }) : stableDuration = stableDuration ??
            Duration(milliseconds: PcdParams.autoCaptureStableMs),
       areaTolerance = areaTolerance ?? PcdParams.autoCaptureAreaTolerance {
    scanner.addListener(_onScanner);
  }

  final ScannerController scanner;
  final Future<void> Function() onTrigger;
  final Duration stableDuration;
  final double areaTolerance;

  DateTime? _stableSince;
  double? _lastNormalizedArea;
  bool _triggered = false;

  /// 0..1 progress untuk UI (mis. ring di shutter button).
  double get progress {
    if (_stableSince == null) return 0;
    final elapsed = DateTime.now().difference(_stableSince!);
    final r = elapsed.inMilliseconds / stableDuration.inMilliseconds;
    return r.clamp(0.0, 1.0);
  }

  bool get isCounting => _stableSince != null;

  void _onScanner() {
    if (!scanner.autoCaptureEnabled || scanner.isCapturing) {
      _reset();
      return;
    }
    if (scanner.detectionState != 'ready' ||
        scanner.documentCorners.length != 4) {
      _reset();
      return;
    }

    final area = _normalizedArea(scanner.documentCorners);
    final last = _lastNormalizedArea;
    _lastNormalizedArea = area;

    if (last == null) {
      _stableSince = DateTime.now();
      notifyListeners();
      return;
    }

    if ((area - last).abs() > areaTolerance) {
      // Korner gerak banyak → reset.
      _stableSince = DateTime.now();
      notifyListeners();
      return;
    }

    if (_stableSince == null) {
      _stableSince = DateTime.now();
      notifyListeners();
      return;
    }

    final elapsed = DateTime.now().difference(_stableSince!);
    if (elapsed >= stableDuration && !_triggered) {
      _triggered = true;
      notifyListeners();
      // Fire and forget; caller bertanggung jawab navigate.
      onTrigger().whenComplete(() {
        _triggered = false;
        _reset();
      });
    } else {
      // Tetap update UI progress ring.
      notifyListeners();
    }
  }

  void _reset() {
    if (_stableSince == null && _lastNormalizedArea == null) return;
    _stableSince = null;
    _lastNormalizedArea = null;
    notifyListeners();
  }

  /// Hitung luas polygon ternormalisasi (dengan asumsi titik 0..1).
  double _normalizedArea(List<Offset> pts) {
    if (pts.length < 3) return 0;
    var area = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      area += pts[i].dx * pts[j].dy - pts[j].dx * pts[i].dy;
    }
    return (area.abs()) / 2.0;
  }

  @override
  void dispose() {
    scanner.removeListener(_onScanner);
    super.dispose();
  }
}
