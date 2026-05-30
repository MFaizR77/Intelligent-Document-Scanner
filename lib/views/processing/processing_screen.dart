// lib/views/processing/processing_screen.dart
//
// Layar yang menjalankan pipeline PCD pada CapturePayload.
// Setelah selesai → navigasi otomatis ke ScanResultScreen dengan ScanArtifact.

import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/config/pcd_params.dart';
import 'package:tugasbesar_pcd/models/capture_payload.dart';
import 'package:tugasbesar_pcd/models/scan_artifact.dart';
import 'package:tugasbesar_pcd/models/scan_engine.dart';
import 'package:tugasbesar_pcd/services/image_processing/document_pipeline.dart';
import 'package:tugasbesar_pcd/services/image_processing/enhancement.dart';
import 'package:tugasbesar_pcd/services/storage/file_service.dart';
import 'package:tugasbesar_pcd/views/processing/scan_result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({
    super.key,
    required this.payload,
    this.returnArtifact = false,
  });

  final CapturePayload payload;

  /// Bila true, screen ini me-`pop` dengan [ScanArtifact] sebagai hasil
  /// (dipakai saat "Tambah Halaman" / "Foto Ulang" pada editor multi-halaman),
  /// alih-alih push ke ScanResultScreen.
  final bool returnArtifact;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  Future<ScanArtifact>? _future;
  // Default ke color (CamScanner-style "Original-Enhanced") supaya hasil
  // tetap natural — BW threshold sering terlalu agresif untuk catatan/buku
  // yang punya gradasi pensil. User bisa ganti mode di scan_result_screen.
  final EnhancementMode _mode = EnhancementMode.color;

  @override
  void initState() {
    super.initState();
    _future = _runPipeline();
  }

  Future<ScanArtifact> _runPipeline() async {
    final outPath = await FileService.newEnhancedJpegPath();
    final profile = PcdParams.profileForLabel(widget.payload.documentPlan);
    final engine = widget.payload.engine;
    return DocumentPipeline.runFromFile(
      inputPath: widget.payload.rawImagePath,
      outputPath: outPath,
      profile: profile,
      mode: _mode,
      overrideCorners: widget.payload.suggestedCornersImage,
      skipGeometry: engine.skipGeometry,
      engine: engine,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Memproses Dokumen',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<ScanArtifact>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _ProcessingState();
          }
          if (snap.hasError) {
            return _ErrorState(
              message: '${snap.error}',
              onRetry: () {
                setState(() {
                  _future = _runPipeline();
                });
              },
            );
          }
          // Sukses → tunda 1 frame lalu pindah ke result screen (atau pop
          // dengan artifact bila dipanggil sebagai "tambah/foto ulang halaman").
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (widget.returnArtifact) {
              Navigator.of(context).pop<ScanArtifact>(snap.data!);
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ScanResultScreen(artifact: snap.data!),
                ),
              );
            }
          });
          return const _ProcessingState();
        },
      ),
    );
  }
}

class _ProcessingState extends StatelessWidget {
  const _ProcessingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: const [
        SizedBox(height: 32),
        Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 5,
            ),
          ),
        ),
        SizedBox(height: 24),
        Center(
          child: Text(
            'Menjalankan pipeline PCD',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            'Canny → Contour → Warp → Shadow Removal → Adaptive Threshold',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 64),
          const SizedBox(height: 12),
          const Text(
            'Pipeline gagal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 18),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
