// lib/services/image_processing/document_pipeline.dart
//
// Orchestrator pipeline PCD untuk **capture path** (foto hi-res hasil
// `takePicture()` atau dari galeri). Bukan untuk frame stream realtime.
//
// Tahapan:
//   1. Load JPG → BGR Mat
//   2. (opsional) Downscale agar long side ≤ 2000px untuk performa
//   3. Deteksi 4 sudut (kalau caller tidak menyediakan korner manual)
//   4. Warp perspective → "bird's eye view"
//   5. Quality assessment (Laplacian variance) untuk metadata
//   6. Enhancement sesuai mode
//   7. Save hasil ke JPG, return [ScanArtifact]
//
// Catatan: dispose Mat dilakukan di finally; ScanArtifact hanya membawa path.

import 'dart:math' as math;
import 'dart:ui';

import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../config/pcd_params.dart';
import '../../models/scan_artifact.dart';
import '../../utils/image_utils.dart';
import 'edge_detection.dart';
import 'enhancement.dart';
import 'perspective_transform.dart';
import 'quality_assessment.dart';

class DocumentPipeline {
  DocumentPipeline._();

  /// Tahap deteksi 4 titik untuk citra hi-res. [bgr] adalah BGR (3-channel).
  static List<Offset> detectCornersImage(cv.Mat bgr, PcdProfile profile) {
    final pts = EdgeDetectionService.findDocumentCornersWith(bgr, profile);
    return pts.map((p) => Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  /// Warp ke persegi panjang lurus.
  static cv.Mat warpToDocument(cv.Mat bgr, List<Offset> cornersImage) {
    final pts = cornersImage
        .map((o) => cv.Point(o.dx.round(), o.dy.round()))
        .toList();
    return PerspectiveTransformService.applyPerspectiveTransform(bgr, pts);
  }

  /// Pipeline lengkap dari path JPG ke path JPG hasil.
  ///
  /// Bila [overrideCorners] disediakan (mis. dari CropScreen manual),
  /// auto-detect dilewati. Jika tidak, pipeline mencoba auto-detect; bila
  /// gagal, gunakan rectangle penuh (no warp) sebagai fallback.
  static Future<ScanArtifact> runFromFile({
    required String inputPath,
    required String outputPath,
    required PcdProfile profile,
    required EnhancementMode mode,
    List<Offset>? overrideCorners,
  }) async {
    final stopwatch = Stopwatch()..start();

    cv.Mat? raw;
    cv.Mat? working;
    cv.Mat? warped;
    cv.Mat? enhanced;

    try {
      raw = ImageUtils.loadJpegToBgrMat(inputPath);
      if (raw.isEmpty) {
        throw StateError('Gagal load gambar: $inputPath');
      }

      // Downscale agar pipeline tidak terlalu berat (≤ ~2000px sisi panjang).
      working = ImageUtils.downscaleLongSide(raw, 2000);
      final scale = working.cols / raw.cols; // sama untuk x dan y

      // Korner: kalau ada override (dari crop screen) skala dulu kalau
      // disediakan dalam koordinat raw. Asumsi: caller selalu memberi
      // koordinat dalam ruang RAW (input file), pipeline yang scale-down.
      List<Offset> cornersWorking;
      if (overrideCorners != null && overrideCorners.length == 4) {
        cornersWorking = overrideCorners
            .map((o) => Offset(o.dx * scale, o.dy * scale))
            .toList();
      } else {
        cornersWorking = detectCornersImage(working, profile);
        if (cornersWorking.length != 4) {
          // Fallback: pakai full frame agar pipeline tetap menghasilkan output.
          cornersWorking = _fullFrameCorners(working);
        }
      }

      warped = warpToDocument(working, cornersWorking);

      enhanced = EnhancementService.enhance(warped, mode, profile: profile);

      // Quality assessment di hasil enhancement (proxy ketajaman akhir).
      final metrics = QualityAssessmentService.evaluate(enhanced);

      final saved = await ImageUtils.saveMatToJpeg(enhanced, outputPath);
      if (!saved) {
        throw StateError('Gagal simpan hasil ke $outputPath');
      }

      stopwatch.stop();

      // Konversi korner ke koordinat RAW (sebelum downscale) supaya UI bisa
      // menggambarnya kembali pada gambar raw.
      final cornersRaw = cornersWorking
          .map((o) => Offset(o.dx / scale, o.dy / scale))
          .toList();

      return ScanArtifact(
        originalPath: inputPath,
        enhancedPath: outputPath,
        cornersImage: cornersRaw,
        documentPlanLabel: profile.label,
        enhancementMode: mode.label,
        blurScore: metrics.blurScore,
        totalDuration: stopwatch.elapsed,
        imageWidth: raw.cols,
        imageHeight: raw.rows,
      );
    } finally {
      enhanced?.dispose();
      warped?.dispose();
      working?.dispose();
      raw?.dispose();
    }
  }

  static List<Offset> _fullFrameCorners(cv.Mat m) {
    final w = m.cols.toDouble();
    final h = m.rows.toDouble();
    // Beri margin 1 px supaya warp tidak edge-case.
    return <Offset>[
      const Offset(0, 0),
      Offset(w - 1, 0),
      Offset(w - 1, h - 1),
      Offset(0, h - 1),
    ];
  }

  /// Util kecil: hitung luas polygon (untuk debugging/validasi).
  // ignore: unused_element
  static double _polygonArea(List<Offset> pts) {
    if (pts.length < 3) return 0;
    var area = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final j = (i + 1) % pts.length;
      area += pts[i].dx * pts[j].dy - pts[j].dx * pts[i].dy;
    }
    return (area.abs()) / 2.0;
  }

  // ignore: unused_element
  static double _max(double a, double b) => math.max(a, b);
}
