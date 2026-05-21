// lib/widgets/document/before_after_slider.dart
//
// Slider sederhana: gambar "after" tampil penuh, gambar "before" muncul
// dari kiri sesuai posisi handle. Drag handle horizontal untuk melihat
// perbandingan PCD before/after.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';

class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    super.key,
    required this.beforePath,
    required this.afterPath,
  });

  final String beforePath;
  final String afterPath;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _ratio = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final clipW = (w * _ratio).clamp(0.0, w);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            setState(() {
              _ratio = ((_ratio * w) + d.delta.dx).clamp(0.0, w) / w;
            });
          },
          onTapDown: (d) {
            setState(() {
              _ratio = (d.localPosition.dx / w).clamp(0.0, 1.0);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // After (full)
              Positioned.fill(
                child: Image.file(
                  File(widget.afterPath),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              // Before (clipped from left)
              ClipRect(
                clipper: _LeftClipper(width: clipW),
                child: Image.file(
                  File(widget.beforePath),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              // Divider line
              Positioned(
                left: clipW - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: AppColors.primary),
              ),
              // Handle
              Positioned(
                left: clipW - 16,
                top: h / 2 - 16,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                  child: const Icon(
                    Icons.compare_arrows,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
              ),
              // Labels
              Positioned(
                left: 10,
                top: 10,
                child: _Tag(label: 'BEFORE', color: Colors.white),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: _Tag(label: 'AFTER', color: AppColors.primary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper({required this.width});
  final double width;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, width.clamp(0.0, size.width), size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) =>
      oldClipper.width != width;
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
