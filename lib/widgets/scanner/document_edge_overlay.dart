import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';

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

class _DocumentEdgePainter extends CustomPainter {
  _DocumentEdgePainter({required this.corners, required this.isReady});

  final List<Offset> corners;
  final bool isReady;

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) {
      return;
    }

    final points = corners.map((point) => _mapPoint(point, size)).toList();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    final edgeColor = isReady ? AppColors.primary : AppColors.danger;
    final fillPaint = Paint()
      ..color = edgeColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = edgeColor.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final edgePaint = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = edgeColor;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, edgePaint);

    for (final point in points) {
      canvas.drawCircle(point, 6, dotPaint);
    }
  }

  Offset _mapPoint(Offset point, Size size) {
    if (size.height >= size.width) {
      return Offset(point.dy * size.width, (1 - point.dx) * size.height);
    }
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _DocumentEdgePainter oldDelegate) {
    return oldDelegate.corners != corners || oldDelegate.isReady != isReady;
  }
}
