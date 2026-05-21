// lib/services/image_processing/quality_assessment.dart
//
// Heuristik PCD untuk menilai kualitas gambar dokumen:
//   - blurScore (Laplacian variance)
//   - meanIntensity (untuk deteksi "terlalu gelap"/"terlalu terang")
//
// Dipakai untuk:
//   - feedback realtime (auto-capture menunggu blurScore di atas threshold)
//   - rapor metadata di ScanResult / laporan akademis
//
// Justifikasi: variance dari Laplacian adalah indikator klasik dari ketajaman
// (Pertuz et al., 2013, "Analysis of focus measure operators"). Citra blur
// memiliki spektrum frekuensi tinggi yang lemah; Laplacian (turunan kedua)
// menangkap energi frekuensi tinggi. Variance-nya proporsional terhadap
// ketajaman.
import 'package:opencv_dart/opencv_dart.dart' as cv;

class QualityMetrics {
  const QualityMetrics({
    required this.blurScore,
    required this.meanIntensity,
  });

  /// Variance(Laplacian(grayscale)). Lebih tinggi = lebih tajam.
  /// Threshold pragmatis di mid-range device: ≥ 80 → tajam.
  final double blurScore;

  /// Rata-rata intensitas pixel (0-255).
  final double meanIntensity;

  bool get isAcceptablySharp => blurScore >= 80.0;
}

class QualityAssessmentService {
  /// Hitung [QualityMetrics] dari Mat (boleh BGR atau gray).
  static QualityMetrics evaluate(cv.Mat src) {
    if (src.isEmpty) {
      return const QualityMetrics(blurScore: 0, meanIntensity: 0);
    }

    cv.Mat? gray;
    cv.Mat? lap;

    try {
      gray = src.channels == 3
          ? cv.cvtColor(src, cv.COLOR_BGR2GRAY)
          : src.clone();

      // CV_64F (depth = 6) supaya tidak ada saturasi pada turunan kedua.
      lap = cv.laplacian(gray, cv.MatType.CV_64F, ksize: 3);
      final stats = cv.meanStdDev(lap);
      final std = stats.$2.val1; // stddev channel 0
      final variance = std * std;

      final meanScalar = cv.mean(gray);
      return QualityMetrics(
        blurScore: variance,
        meanIntensity: meanScalar.val1,
      );
    } finally {
      lap?.dispose();
      gray?.dispose();
    }
  }
}
