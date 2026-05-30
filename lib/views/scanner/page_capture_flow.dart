// lib/views/scanner/page_capture_flow.dart
//
// Helper bersama untuk menangkap SATU halaman dokumen melalui salah satu
// engine (Kamera PCD / Kamera ML Kit / Galeri), menjalankan pipeline PCD,
// dan mengembalikan [ScanArtifact] siap pakai.
//
// Dipakai oleh editor hasil scan (ScanResultScreen) maupun editor dokumen
// tersimpan (ScanDetailScreen) supaya alur "tambah halaman" / "foto ulang"
// konsisten di kedua tempat.

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../models/capture_payload.dart';
import '../../models/scan_artifact.dart';
import '../../services/scanner/mlkit_document_scanner_service.dart';
import '../processing/processing_screen.dart';
import 'crop_screen.dart';
import 'picker_entry.dart';
import 'scanner_screen.dart';

class PageCaptureFlow {
  PageCaptureFlow._();

  /// Tampilkan pemilih sumber lalu hasilkan satu [ScanArtifact], atau null
  /// kalau user membatalkan di tahap mana pun.
  ///
  /// [documentPlan] menentukan profil parameter PCD (Auto/A4/Buku/KTP).
  static Future<ScanArtifact?> captureOne(
    BuildContext context, {
    required String documentPlan,
  }) async {
    final payload = await _pickPayload(context, documentPlan: documentPlan);
    if (payload == null || !context.mounted) return null;
    return _processPayload(context, payload);
  }

  static Future<CapturePayload?> _pickPayload(
    BuildContext context, {
    required String documentPlan,
  }) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Kamera (PCD)'),
              onTap: () => Navigator.pop(ctx, 'pcd'),
            ),
            if (MlkitDocumentScannerService.isSupported)
              ListTile(
                leading: const Icon(Icons.document_scanner_rounded,
                    color: AppColors.blue),
                title: const Text('Kamera (ML Kit)'),
                onTap: () => Navigator.pop(ctx, 'mlkit'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Colors.white70),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return null;

    switch (source) {
      case 'gallery':
        final picked =
            await PickerEntry.pickPayloadFromGallery(documentPlan: documentPlan);
        if (picked == null || !context.mounted) return null;
        // Galeri perlu CropScreen manual (tidak ada deteksi realtime).
        return Navigator.of(context).push<CapturePayload>(
          MaterialPageRoute<CapturePayload>(
            builder: (_) => CropScreen(payload: picked),
          ),
        );
      case 'pcd':
      case 'mlkit':
        // Scanner dalam mode "return payload": tangani kamera/crop sendiri.
        return Navigator.of(context).push<CapturePayload>(
          MaterialPageRoute<CapturePayload>(
            builder: (_) => ScannerScreen(
              isActive: true,
              returnPayload: true,
              forceEngine: source == 'mlkit',
            ),
          ),
        );
    }
    return null;
  }

  static Future<ScanArtifact?> _processPayload(
    BuildContext context,
    CapturePayload payload,
  ) {
    return Navigator.of(context).push<ScanArtifact>(
      MaterialPageRoute<ScanArtifact>(
        builder: (_) => ProcessingScreen(
          payload: payload,
          returnArtifact: true,
        ),
      ),
    );
  }
}
