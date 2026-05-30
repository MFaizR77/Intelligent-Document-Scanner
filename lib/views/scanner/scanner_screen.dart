import 'package:camera/camera.dart';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/controllers/auto_capture_controller.dart';
import 'package:tugasbesar_pcd/controllers/scanner_controller.dart';
import 'package:tugasbesar_pcd/models/capture_payload.dart';
import 'package:tugasbesar_pcd/models/scan_engine.dart';
import 'package:tugasbesar_pcd/services/scanner/mlkit_document_scanner_service.dart';

import 'package:tugasbesar_pcd/views/processing/processing_screen.dart';
import 'package:tugasbesar_pcd/views/scanner/camera_plan_screen.dart';
import 'package:tugasbesar_pcd/views/scanner/crop_screen.dart';
import 'package:tugasbesar_pcd/views/scanner/picker_entry.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';
import 'package:tugasbesar_pcd/widgets/scanner/document_edge_overlay.dart';
import 'package:tugasbesar_pcd/widgets/scanner/scanner_controls.dart';
import 'package:tugasbesar_pcd/widgets/scanner/scanner_status_chip.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, this.isActive = true});

  /// True bila tab Scan sedang aktif di [HomeShell]. Saat berubah jadi false
  /// (user pindah tab), kamera + isolate dilepas supaya tidak terus berjalan
  /// di background (penyebab HP panas / kebocoran kamera).
  final bool isActive;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  late final ScannerController _controller;
  late final AutoCaptureController _autoCapture;

  bool _mlkitBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ScannerController();
    _autoCapture = AutoCaptureController(
      scanner: _controller,
      onTrigger: _runCaptureFlow,
    );
    // Kamera TIDAK di-start otomatis. User memilih mode dulu (chooser),
    // kamera baru menyala on-demand saat memilih "Scan PCD".
  }

  @override
  void didUpdateWidget(covariant ScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tab berpindah dari Scan ke tab lain → lepas kamera.
    if (oldWidget.isActive && !widget.isActive) {
      _controller.releaseCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // App ke background / tidak aktif → lepas kamera. Sensor + isolate hanya
    // hidup ketika scanner benar-benar tampil dan app di foreground.
    if (state != AppLifecycleState.resumed) {
      _controller.releaseCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCapture.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openPlanSettings() async {
    final result = await Navigator.of(context).push<CameraPlanResult>(
      MaterialPageRoute<CameraPlanResult>(
        builder: (_) => CameraPlanScreen(
          currentPlan: _controller.documentPlan,
          currentAutoCapture: _controller.autoCaptureEnabled,
        ),
      ),
    );
    if (result == null) return;
    _controller.updatePlan(
      plan: result.documentPlan,
      autoCapture: result.autoCaptureEnabled,
    );
  }

  /// Mulai jalur PCD: nyalakan kamera realtime (Canny + contour + overlay).
  Future<void> _startPcdScan() async {
    await _controller.initializeCameraFlow();
  }

  /// Jalur ML Kit Document Scanner (SCANNER_MODE_BASE). UI scan disediakan
  /// Google Play Services; hasilnya JPG yang sudah ter-crop & lurus, langsung
  /// masuk pipeline enhancement PCD (tanpa CropScreen, tanpa warp ulang).
  Future<void> _startMlkitScan() async {
    if (_mlkitBusy) return;
    setState(() => _mlkitBusy = true);
    try {
      final rawPath = await MlkitDocumentScannerService.scanToRawJpeg();
      if (rawPath == null || !mounted) return;

      final payload = CapturePayload(
        rawImagePath: rawPath,
        documentPlan: _controller.documentPlan,
        engine: ScanEngine.mlkit,
      );

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProcessingScreen(payload: payload),
        ),
      );
    } on MlkitScanException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ML Kit Scanner gagal: $e')),
      );
    } finally {
      if (mounted) setState(() => _mlkitBusy = false);
    }
  }

  Future<void> _openGallery() async {
    await PickerEntry.pickFromGallery(
      context,
      documentPlan: _controller.documentPlan,
    );
    if (!mounted) return;
    // Galeri memakai pipeline PCD; kalau kamera aktif, lanjutkan stream.
    if (_controller.isCameraReady) {
      await _controller.resumeDetectionStream();
    }
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
        final showChooser = !_controller.isCameraReady &&
            !_controller.isLoadingCamera &&
            !_controller.permissionDenied;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: _CameraStage(controller: _controller)),

                // Status chip + tombol tutup kamera (hanya saat kamera aktif).
                if (_controller.isCameraReady) ...[
                  Positioned(
                    top: 26,
                    left: 22,
                    right: 22,
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: Icons.close,
                          onPressed: _controller.releaseCamera,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ScannerStatusChip(
                            isReady: _controller.isDocumentReady,
                            statusText: _controller.statusText,
                          ),
                        ),
                      ],
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
                      onCapture: _runCaptureFlow,
                      onPlan: _openPlanSettings,
                      onGallery: _openGallery,
                    ),
                  ),
                ],

                // Chooser mode (default, kamera mati).
                if (showChooser)
                  Positioned.fill(
                    child: _ScanChooser(
                      plan: _controller.documentPlan,
                      mlkitSupported: MlkitDocumentScannerService.isSupported,
                      mlkitBusy: _mlkitBusy,
                      onPlan: _openPlanSettings,
                      onScanPcd: _startPcdScan,
                      onScanMlkit: _startMlkitScan,
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
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Layar pemilihan mode scan. Kamera belum menyala di sini — sesuai prinsip
/// "kamera hanya hidup saat dibutuhkan".
class _ScanChooser extends StatelessWidget {
  const _ScanChooser({
    required this.plan,
    required this.mlkitSupported,
    required this.mlkitBusy,
    required this.onPlan,
    required this.onScanPcd,
    required this.onScanMlkit,
    required this.onGallery,
  });

  final String plan;
  final bool mlkitSupported;
  final bool mlkitBusy;
  final VoidCallback onPlan;
  final VoidCallback onScanPcd;
  final VoidCallback onScanMlkit;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF06140D), AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        children: [
          const Text(
            'Pindai Dokumen',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih engine pemindaian. Keduanya diproses oleh pipeline '
            'enhancement PCD yang sama.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 22),

          // Pemilih mode dokumen (plan).
          InkWell(
            onTap: onPlan,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.primary),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Mode Dokumen',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    plan,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white38),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _ScanModeCard(
            icon: Icons.camera_alt_rounded,
            title: 'Scan PCD',
            subtitle:
                'Deteksi tepi realtime buatan sendiri (Canny + contour + '
                'homography). Overlay & auto-capture.',
            accent: AppColors.primary,
            onTap: onScanPcd,
          ),
          const SizedBox(height: 14),
          _ScanModeCard(
            icon: Icons.document_scanner_rounded,
            title: 'Scan ML Kit',
            subtitle: mlkitSupported
                ? 'Google ML Kit Document Scanner. Crop & koreksi perspektif '
                    'otomatis, lalu enhancement PCD.'
                : 'Hanya tersedia di Android.',
            accent: AppColors.blue,
            enabled: mlkitSupported && !mlkitBusy,
            busy: mlkitBusy,
            onTap: onScanMlkit,
          ),
          const SizedBox(height: 14),

          OutlinedButton.icon(
            onPressed: onGallery,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text(
              'Pilih dari Galeri',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanModeCard extends StatelessWidget {
  const _ScanModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.enabled = true,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: accent,
                        ),
                      )
                    : Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accent.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
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
      // Layout HAKIM: preview di-fit pakai aspect ratio asli kamera lalu
      // di-center. Area sekitar otomatis diisi oleh Scaffold.background
      // (hitam) → efek "background dihitamkan". Edge detection overlay
      // tepat berada di atas preview, bukan tergerus oleh crop cover.
      return Center(
        child: AspectRatio(
          aspectRatio: 1 / nativeController.value.aspectRatio,
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
      );
    }

    // Saat chooser tampil, background gradient diurus oleh _ScanChooser.
    return const ColoredBox(color: AppColors.background);
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
