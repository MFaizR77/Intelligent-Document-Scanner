// lib/widgets/scanner/draggable_corner.dart
import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';

/// Handle bulat untuk men-drag salah satu sudut polygon di CropScreen.
class DraggableCornerHandle extends StatelessWidget {
  const DraggableCornerHandle({
    super.key,
    required this.position,
    required this.onDrag,
    this.size = 28,
  });

  /// Posisi titik dalam koordinat layar (Stack child Positioned).
  final Offset position;
  final ValueChanged<Offset> onDrag;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) {
          onDrag(position + details.delta);
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.30),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 6),
            ],
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
