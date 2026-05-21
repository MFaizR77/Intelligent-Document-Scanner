import 'package:flutter/material.dart';

/// Overlay widget untuk menampilkan deteksi tepi dokumen secara realtime di atas camera stream.
///
/// Menerima 4 koordinat titik tepi dokumen dan nilai confidence untuk menentukan warna.
/// - Confidence >= 0.5: Warna hijau (ready)
/// - Confidence < 0.5: Warna merah (searching)
///
/// Widget ini akan terus me-update setiap kali corners atau confidence berubah.
class DocumentEdgeOverlay extends StatelessWidget {
  const DocumentEdgeOverlay({
    super.key,
    required this.corners,
    required this.isReady,
  });

  final List<Offset> corners;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _DocumentEdgePainter(corners: corners, isReady: isReady),
      ),
    );
  }
}

/// CustomPainter untuk menggambar overlay tepi dokumen dengan deteksi status realtime.
///
/// Pipeline rendering:
/// 1. Scale koordinat dari imageSize ke canvas size dengan memperhitungkan rotasi 90°
/// 2. Tentukan warna berdasarkan confidence threshold (>= 0.5 = green, < 0.5 = red)
/// 3. Gambar poligon dengan ketebalan 3.0
class _DocumentEdgePainter extends CustomPainter {
  _DocumentEdgePainter({required this.corners, required this.isReady});

  final List<Offset> corners;
  final bool isReady;

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) {
      return;
    }

    // Koordinat corners berupa rasio 0.0 - 1.0, petakan langsung ke kanvas.
    final points = corners
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList();

    // Step 2: Tentukan warna berdasarkan status siap/tidak siap
    final edgeColor = isReady ? Colors.green : Colors.red;

    // Step 3: Gambar poligon dengan ketebalan 3.0
    _drawPolygon(canvas, points, edgeColor);
  }

  /// Menggambar poligon tepi dokumen dengan ketebalan 3.0.
  void _drawPolygon(Canvas canvas, List<Offset> points, Color edgeColor) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    // Gambar garis poligon dengan ketebalan 3.0
    final edgePaint = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, edgePaint);
  }

  @override
  bool shouldRepaint(covariant _DocumentEdgePainter oldDelegate) {
    if (oldDelegate.isReady != isReady) {
      return true;
    }

    // Check if corners list length changed
    if (oldDelegate.corners.length != corners.length) {
      return true;
    }

    // Check if any corner position changed
    for (int i = 0; i < corners.length; i++) {
      if (oldDelegate.corners[i] != corners[i]) {
        return true;
      }
    }

    return false;
  }
}
