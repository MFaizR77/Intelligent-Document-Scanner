// lib/services/storage/pdf_export_service.dart
//
// Gabungkan satu/lebih file JPG ke PDF A4. Tiap halaman = 1 gambar
// di-fit "contain" pada A4 (margin 24).

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'file_service.dart';

class PdfExportService {
  PdfExportService._();
  static final PdfExportService instance = PdfExportService._();

  /// Buat PDF dari daftar path JPG. Return path file PDF yang sudah ditulis.
  Future<String> exportImages(
    List<String> imagePaths, {
    String? hint,
  }) async {
    final outPath = await FileService.newPdfPath(hint: hint);
    final doc = pw.Document();

    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final pdfBytes = await doc.save();
    final file = File(outPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(pdfBytes);
    return outPath;
  }
}
