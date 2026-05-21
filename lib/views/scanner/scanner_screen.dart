import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/controllers/auto_capture_controller.dart';
import 'package:tugasbesar_pcd/controllers/scanner_controller.dart';
import 'package:tugasbesar_pcd/models/capture_payload.dart';

import 'package:tugasbesar_pcd/views/processing/processing_screen.dart';
import 'package:tugasbesar_pcd/views/scanner/camera_plan_screen.dart';
import 'package:tugasbesar_pcd/views/scanner/crop_screen.dart';
import 'package:tugasbesar_pcd/views/scanner/picker_entry.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';
import 'package:tugasbesar_pcd/widgets/scanner/document_edge_overlay.dart';
import 'package:tugasbesar_pcd/widgets/scanner/scanner_controls.dart';
import 'package:tugasbesar_pcd/widgets/scanner/scanner_status_chip.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final ScannerController _controller;
  late final AutoCaptureController _autoCapture;

  @override
  void initState() {
    super.initState();
    _controller = ScannerController();
    _autoCapture = AutoCaptureController(
      scanner: _controller,
      onTrigger: _runCaptureFlow,
    );
  }

  @override
  void dispose() {
    _autoCapture.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openCameraPlan() async {
    if (!_controller.isCameraReady) {
      await _controller.initializeCameraFlow();
      if (!_controller.isCameraReady || !mounted) {
        return;
      }
    }

    final result = await Navigator.of(context).push<CameraPlanResult>(
      MaterialPageRoute<CameraPlanResult>(
        builder: (_) => CameraPlanScreen(
          currentPlan: _controller.documentPlan,
          currentAutoCapture: _controller.autoCaptureEnabled,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    _controller.updatePlan(
      plan: result.documentPlan,
      autoCapture: result.autoCaptureEnabled,
    );
  }

  void _captureOrOpenPlan() async {
    if (!_controller.isCameraReady) {
      _controller.initializeCameraFlow();
      return;
    }

    if (_controller.isDocumentReady) {
      await _runCaptureFlow();
      return;
    }

    _openCameraPlan();
  }

  Future<void> _openGallery() async {
    await PickerEntry.pickFromGallery(
      context,
      documentPlan: _controller.documentPlan,
    );
    if (!mounted) return;
    await _controller.resumeDetectionStream();
  }

  Future<void> _runCaptureFlow() async {
    final payload = await _controller.capturePhoto();
    if (payload == null || !mounted) {
      return;
    }

    // Layar crop dulu (manual corner adjustment), baru pipeline.
    final adjusted = await Navigator.of(context).push<CapturePayload>(
      MaterialPageRoute<CapturePayload>(
        builder: (_) => CropScreen(payload: payload),
      ),
    );

    if (!mounted) return;
    if (adjusted == null) {
      // User batal — restart stream realtime.
      await _controller.resumeDetectionStream();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProcessingScreen(payload: adjusted),
      ),
    );

    if (!mounted) return;
    await _controller.resumeDetectionStream();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _autoCapture]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: _CameraStage(controller: _controller)),
                Positioned(
                  top: 26,
                  left: 22,
                  right: 22,
                  child: ScannerStatusChip(
                    isReady: _controller.isDocumentReady,
                    statusText: _controller.statusText,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ScannerControls(
                    isReady: _controller.isDocumentReady,
                    autoCaptureEnabled: _controller.autoCaptureEnabled,
                    plan: _controller.documentPlan,
                    flashEnabled: _controller.flashEnabled,
                    captureProgress: _autoCapture.progress,
                    onFlash: _controller.toggleFlash,
                    onCapture: _captureOrOpenPlan,
                    onPlan: _openCameraPlan,
                    onGallery: _openGallery,
                  ),
                ),
                if (_controller.isLoadingCamera)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black54,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (_controller.permissionDenied)
                  Positioned.fill(
                    child: _PermissionOverlay(
                      onRetry: _controller.initializeCameraFlow,
                    ),
                  ),
                if (!_controller.isCameraReady && !_controller.isLoadingCamera)
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 190,
                    child: AppPrimaryButton(
                      label: 'Mulai Scan',
                      icon: Icons.camera_alt,
                      onPressed: _controller.initializeCameraFlow,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CameraStage extends StatelessWidget {
  const _CameraStage({required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    final CameraController? nativeController =
        controller.nativeCameraController;

    if (controller.isCameraReady && nativeController != null) {
      final size = MediaQuery.of(context).size;
      final deviceRatio = size.width / size.height;
      double cameraRatio = nativeController.value.aspectRatio;
      if (cameraRatio > 1) cameraRatio = 1 / cameraRatio;

      double scale = 1.0;
      if (deviceRatio > cameraRatio) {
        scale = deviceRatio / cameraRatio;
      } else {
        scale = cameraRatio / deviceRatio;
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: AspectRatio(
                  aspectRatio: cameraRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(nativeController),
                      DocumentEdgeOverlay(
                        corners: controller.documentCorners,
                        isReady: controller.isDocumentReady,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (controller.enhancedPreview != null)
            Positioned(
              right: 20,
              bottom: 210,
              child: _EnhancedPreview(bytes: controller.enhancedPreview!),
            ),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF06140D), AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Transform.rotate(
          angle: -0.11,
          child: Container(
            width: 245,
            height: 360,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary, width: 3),
            ),
            child: const Icon(
              Icons.description,
              color: Colors.black26,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

class _EnhancedPreview extends StatelessWidget {
  const _EnhancedPreview({required this.bytes});

  final List<int> bytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 96,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class _PermissionOverlay extends StatelessWidget {
  const _PermissionOverlay({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white54,
              size: 58,
            ),
            const SizedBox(height: 16),
            const Text(
              'Izin kamera belum diberikan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Berikan izin kamera agar edge detection dokumen dapat berjalan realtime.',
              style: TextStyle(color: Colors.white60, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(label: 'Coba lagi', onPressed: onRetry),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Buka pengaturan aplikasi'),
            ),
          ],
        ),
      ),
    );
  }
}
