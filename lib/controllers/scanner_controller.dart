import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tugasbesar_pcd/controllers/camera_controller.dart';
import 'package:tugasbesar_pcd/controllers/isolate_manager.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';

class ScannerController extends ChangeNotifier {
  ScannerController({
    AppCameraController? cameraController,
    IsolateManager? isolateManager,
  }) : _cameraController = cameraController ?? AppCameraController(),
       _isolateManager = isolateManager ?? IsolateManager();

  final AppCameraController _cameraController;
  final IsolateManager _isolateManager;

  bool isLoadingCamera = false;
  bool isCameraReady = false;
  bool permissionDenied = false;
  bool isStreaming = false;
  bool isProcessingFrame = false;
  bool flashEnabled = false;

  String statusText = 'Tekan Mulai Scan untuk membuka kamera';
  String detectionState = 'idle';
  String documentPlan = 'Auto';
  bool autoCaptureEnabled = true;
  double confidence = 0;
  Color documentEdgeColor = AppColors.danger;
  Uint8List? enhancedPreview;
  List<Offset> documentCorners = const [];
  int imageWidth = 0;
  int imageHeight = 0;

  static const double minConfidenceForReady = 0.2;

  DateTime _lastFrameSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isDisposed = false;
  bool _cleanupScheduled = false;

  CameraController? get nativeCameraController => _cameraController.controller;
  bool get isDocumentReady => detectionState == 'ready';

  Future<void> initializeCameraFlow() async {
    if (_isDisposed || isLoadingCamera) {
      return;
    }

    isLoadingCamera = true;
    permissionDenied = false;
    statusText = 'Meminta izin kamera...';
    detectionState = 'loading';
    notifyListeners();

    final permission = await Permission.camera.request();
    if (_isDisposed) {
      return;
    }

    if (!permission.isGranted) {
      isLoadingCamera = false;
      isCameraReady = false;
      permissionDenied = true;
      statusText = 'Izin kamera diperlukan untuk memindai dokumen.';
      detectionState = 'permission';
      notifyListeners();
      return;
    }

    try {
      await _cameraController.initialize();
      if (_isDisposed) {
        await _cameraController.dispose();
        return;
      }

      await _startDetectionStream();

      if (_isDisposed) {
        return;
      }

      isLoadingCamera = false;
      isCameraReady = _cameraController.isInitialized;
      permissionDenied = false;
      statusText = 'Arahkan kamera ke satu dokumen utama';
      detectionState = 'searching';
      notifyListeners();
    } catch (error) {
      isLoadingCamera = false;
      isCameraReady = false;
      permissionDenied = false;
      isStreaming = false;
      statusText = 'Gagal inisialisasi kamera: $error';
      detectionState = 'error';
      notifyListeners();
    }
  }

  void updatePlan({required String plan, required bool autoCapture}) {
    if (_isDisposed) {
      return;
    }

    documentPlan = plan;
    autoCaptureEnabled = autoCapture;
    statusText = 'Plan aktif: $plan';
    notifyListeners();
  }

  Future<void> toggleFlash() async {
    if (_isDisposed) {
      return;
    }

    final controller = nativeCameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    flashEnabled = !flashEnabled;
    await controller.setFlashMode(
      flashEnabled ? FlashMode.torch : FlashMode.off,
    );
    notifyListeners();
  }

  Future<void> _startDetectionStream() async {
    if (_isDisposed) {
      return;
    }

    final controller = nativeCameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    await _isolateManager.spawnProcessingIsolate(_handleProcessingResult);

    if (!_cameraController.isStreamingImages) {
      await _cameraController.startImageStream(_onCameraImage);
    }

    isStreaming = true;
  }

  void _onCameraImage(CameraImage image) {
    if (_isDisposed) {
      return;
    }

    final now = DateTime.now();
    if (!_isolateManager.isReady || isProcessingFrame) {
      return;
    }

    if (now.difference(_lastFrameSent).inMilliseconds < 180) {
      return;
    }

    isProcessingFrame = true;
    _lastFrameSent = now;
    final sent = _isolateManager.processFrame(image);
    if (!sent) {
      isProcessingFrame = false;
    }
  }

  void _handleProcessingResult(Map<String, dynamic> result) {
    if (_isDisposed) {
      return;
    }

    debugPrint('==== HASIL ISOLATE: $result ====');
    isProcessingFrame = false;

    final status = result['status']?.toString() ?? 'searching';
    final rawConfidence = (result['confidence'] as num?)?.toDouble() ?? 0;
    final preview = result['preview'];
    final rawCorners = result['corners'];
    final rawImageWidth = (result['imageWidth'] as num?)?.toInt() ?? 0;
    final rawImageHeight = (result['imageHeight'] as num?)?.toInt() ?? 0;
    final corners = <Offset>[];

    imageWidth = rawImageWidth;
    imageHeight = rawImageHeight;

    if (rawCorners is List) {
      for (final item in rawCorners) {
        if (item is List && item.length >= 2) {
          final x = (item[0] as num).toDouble().clamp(0.0, 1.0);
          final y = (item[1] as num).toDouble().clamp(0.0, 1.0);
          corners.add(Offset(x, y));
        }
      }
    }

    detectionState = status;
    documentCorners = corners;
    confidence = rawConfidence;
    documentEdgeColor = _determineDocumentEdgeColor(status, rawConfidence);
    if (preview is Uint8List) {
      enhancedPreview = preview;
    }
    statusText = switch (status) {
      'ready' => 'Dokumen terdeteksi',
      'error' => 'Pipeline PCD belum stabil pada frame ini',
      _ => 'Arahkan kamera ke satu dokumen utama',
    };
    notifyListeners();
  }

  Color _determineDocumentEdgeColor(String status, double confidenceValue) {
    if (status == 'ready' && confidenceValue >= minConfidenceForReady) {
      return AppColors.primary;
    }

    return AppColors.danger;
  }

  Future<void> stopDetectionStream({bool force = false}) async {
    if (_isDisposed && !force) {
      return;
    }

    await _cameraController.stopImageStream();
    isStreaming = false;
  }

  @override
  void dispose() {
    if (_cleanupScheduled) {
      super.dispose();
      return;
    }

    _isDisposed = true;
    _cleanupScheduled = true;
    unawaited(_cleanupResources());
    super.dispose();
  }

  Future<void> _cleanupResources() async {
    await stopDetectionStream(force: true);
    _isolateManager.dispose();
    await _cameraController.dispose();
  }
}
