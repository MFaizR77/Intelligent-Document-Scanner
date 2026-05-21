// lib/views/scanner/picker_entry.dart
//
// Helper untuk membuka galeri → langsung masuk CropScreen seperti
// jalur kamera, sehingga pipeline yang sama bisa dipakai untuk gambar
// dari sumber lain (demo offline/reproducible).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tugasbesar_pcd/models/capture_payload.dart';
import 'package:tugasbesar_pcd/services/storage/file_service.dart';
import 'package:tugasbesar_pcd/views/processing/processing_screen.dart';
import 'package:tugasbesar_pcd/views/scanner/crop_screen.dart';

class PickerEntry {
  PickerEntry._();

  /// Pilih satu gambar dari galeri, copy ke direktori scans/raw,
  /// lalu push CropScreen → ProcessingScreen.
  ///
  /// Kalau user cancel, return tanpa side-effect.
  static Future<void> pickFromGallery(
    BuildContext context, {
    String documentPlan = 'Auto',
  }) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (file == null) return;

    // Copy ke direktori app supaya path stabil dan tidak tergantung URI
    // sementara dari sistem.
    final dst = await FileService.newRawJpegPath();
    await File(file.path).copy(dst);

    if (!context.mounted) return;
    final initial = CapturePayload(
      rawImagePath: dst,
      documentPlan: documentPlan,
    );

    final adjusted = await Navigator.of(context).push<CapturePayload>(
      MaterialPageRoute<CapturePayload>(
        builder: (_) => CropScreen(payload: initial),
      ),
    );
    if (adjusted == null) return;

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProcessingScreen(payload: adjusted),
      ),
    );
  }
}
