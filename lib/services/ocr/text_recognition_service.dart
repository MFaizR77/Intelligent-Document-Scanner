// lib/services/ocr/text_recognition_service.dart
//
// Wrapper tipis di atas google_mlkit_text_recognition.
// **Catatan ML Kit**: jalan di main isolate (recognizer Java/ObjC tidak
// lintas-isolate-safe). Karena dipanggil on-tap, bukan per-frame, ini aman.
//
// First-run di Android: model di-download oleh Google Play Services (~10 MB).
// Setelah itu offline.

import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrLine {
  const OcrLine({required this.text, required this.bbox});
  final String text;
  final Rect bbox;
}

class OcrResult {
  const OcrResult({
    required this.fullText,
    required this.lines,
    required this.latency,
  });

  final String fullText;
  final List<OcrLine> lines;
  final Duration latency;

  bool get isEmpty => fullText.trim().isEmpty;
}

class TextRecognitionService {
  TextRecognitionService({TextRecognitionScript script = TextRecognitionScript.latin})
    : _recognizer = TextRecognizer(script: script);

  final TextRecognizer _recognizer;

  /// Jalankan OCR pada file gambar (sudah hasil PCD enhanced).
  /// Asumsi: file readable; caller bertanggung jawab path-nya valid.
  Future<OcrResult> recognize(File imageFile) async {
    final sw = Stopwatch()..start();
    final input = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(input);
    sw.stop();

    final lines = <OcrLine>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final r = line.boundingBox;
        lines.add(
          OcrLine(
            text: line.text,
            bbox: Rect.fromLTRB(
              r.left.toDouble(),
              r.top.toDouble(),
              r.right.toDouble(),
              r.bottom.toDouble(),
            ),
          ),
        );
      }
    }

    return OcrResult(
      fullText: result.text,
      lines: lines,
      latency: sw.elapsed,
    );
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
