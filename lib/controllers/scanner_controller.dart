import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tugasbesar_pcd/controllers/camera_controller.dart';
import 'package:tugasbesar_pcd/controllers/isolate_manager.dart';
import 'package:tugasbesar_pcd/models/capture_payload.dart';
import 'package:tugasbesar_pcd/services/storage/file_service.dart';

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
  bool isCapturing = false;
  bool flashEnabled = false;

  String statusText = 'Tekan Mulai Scan untuk membuka kamera';
  String detectionState = 'idle';
  String documentPlan = 'Auto';
  bool autoCaptureEnabled = true;
  double confidence = 0;
  Uint8List? enhancedPreview;
  List<Offset> documentCorners = const [];

  /// Frame size terakhir yang dipakai isolate (dari Y-plane).
  /// Berguna untuk konversi koordinat overlay → image saat passing ke crop.
  int _lastFrameWidth = 0;
  int _lastFrameHeight = 0;

  DateTime _lastFrameSent = DateTime.fromMillisecondsSinceEpoch(0);

  CameraController? get nativeCameraController => _cameraController.controller;
  bool get isDocumentReady => detectionState == 'ready';

  Future<void> initializeCameraFlow() async {
    if (isLoadingCamera) {
      return;
    }

    isLoadingCamera = true;
    permissionDenied = false;
    statusText = 'Meminta izin kamera...';
    detectionState = 'loading';
    notifyListeners();

    final permission = await Permission.camera.request();
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
      await _startDetectionStream();

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
    documentPlan = plan;
    autoCaptureEnabled = autoCapture;
    statusText = 'Plan aktif: $plan';
    notifyListeners();
  }

  Future<void> toggleFlash() async {
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

  /// Ambil foto hi-res, simpan ke app documents, lalu kembalikan payload
  /// untuk diteruskan ke layar berikutnya (CropScreen / ProcessingScreen).
  ///
  /// Penting: stream realtime di-pause selama capture untuk menghindari
  /// kontensi resource pada plugin camera lama (^0.10.x).
  Future<CapturePayload?> capturePhoto() async {
    final controller = nativeCameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        isCapturing) {
      return null;
    }

    isCapturing = true;
    statusText = 'Mengambil foto...';
    notifyListeners();

    // Snapshot korner & ukuran frame realtime SEBELUM stop stream, supaya
    // payload masih membawa hint untuk crop screen.
    final suggestedCorners = documentCorners.isEmpty
        ? null
        : List<Offset>.unmodifiable(documentCorners);
    final frameW = _lastFrameWidth;
    final frameH = _lastFrameHeight;

    try {
      // Pause stream supaya takePicture() tidak konflik di sebagian device.
      if (controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {
          // Kadang stream sudah dihentikan oleh native lifecycle.
        }
        isStreaming = false;
      }

      final XFile shot = await controller.takePicture();
      final dst = await FileService.newRawJpegPath();
      await File(shot.path).copy(dst);

      // Best-effort: buang file temp dari plugin camera.
      try {
        await File(shot.path).delete();
      } catch (_) {}

      // Catatan: koordinat realtime ternormalisasi (0..1) terhadap UKURAN
      // FRAME STREAM (bukan ukuran foto hi-res). Kita simpan saja sebagai
      // hint relatif; crop_screen akan memetakannya ke koordinat foto saat
      // foto sudah dimuat.
      final imageHints = (frameW > 0 && frameH > 0)
          ? <Offset>[
              for (final c in (suggestedCorners ?? const <Offset>[]))
                Offset(c.dx, c.dy),
            ]
          : null;

      return CapturePayload(
        rawImagePath: dst,
        documentPlan: documentPlan,
        suggestedCornersImage: imageHints,
        imageWidth: frameW > 0 ? frameW : null,
        imageHeight: frameH > 0 ? frameH : null,
      );
    } catch (error) {
      statusText = 'Gagal capture: $error';
      detectionState = 'error';
      notifyListeners();
      return null;
    } finally {
      isCapturing = false;
      notifyListeners();
    }
  }

  /// Mulai ulang stream realtime setelah balik dari layar berikutnya.
  Future<void> resumeDetectionStream() async {
    final controller = nativeCameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (!controller.value.isStreamingImages) {
      try {
        await controller.startImageStream(_onCameraImage);
        isStreaming = true;
      } catch (error) {
        statusText = 'Gagal restart stream: $error';
        notifyListeners();
      }
    }
  }

  Future<void> _startDetectionStream() async {
    final controller = nativeCameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    await _isolateManager.spawnProcessingIsolate(_handleProcessingResult);

    if (!controller.value.isStreamingImages) {
      await controller.startImageStream(_onCameraImage);
    }

    isStreaming = true;
  }

  void _onCameraImage(CameraImage image) {
    final now = DateTime.now();
    if (!_isolateManager.isReady || isProcessingFrame || isCapturing) {
      return;
    }

    if (now.difference(_lastFrameSent).inMilliseconds < 180) {
      return;
    }

    isProcessingFrame = true;
    _lastFrameSent = now;
    _lastFrameWidth = image.width;
    _lastFrameHeight = image.height;
    final sent = _isolateManager.processFrame(image);
    if (!sent) {
      isProcessingFrame = false;
    }
  }

  void _handleProcessingResult(Map<String, dynamic> result) {
    isProcessingFrame = false;

    final status = result['status']?.toString() ?? 'searching';
    final rawConfidence = (result['confidence'] as num?)?.toDouble() ?? 0;
    final preview = result['preview'];
    final rawCorners = result['corners'];
    final corners = <Offset>[];

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
    documentCorners = status == 'ready' ? corners : const [];
    confidence = rawConfidence;
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

  Future<void> stopDetectionStream() async {
    final controller = nativeCameraController;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // Stream may already be stopped by native camera lifecycle.
      }
    }
    isStreaming = false;
  }

  @override
  void dispose() {
    stopDetectionStream();
    _isolateManager.dispose();
    _cameraController.dispose();
    super.dispose();
  }
}
