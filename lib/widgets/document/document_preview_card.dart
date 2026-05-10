import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';

class DocumentPreviewCard extends StatelessWidget {
  const DocumentPreviewCard({
    super.key,
    this.qualityLabel = '97%',
    this.tagColor = AppColors.primary,
    this.large = false,
  });

  final String qualityLabel;
  final Color tagColor;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: large ? 0.72 : 0.9,
      child: Container(
        padding: EdgeInsets.all(large ? 16 : 12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(large ? 8 : 10),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18)],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Line(
                    widthFactor: 0.82,
                    height: large ? 10 : 6,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 8),
                  _Line(
                    widthFactor: 0.62,
                    height: large ? 8 : 5,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.black12, height: 1),
                  const SizedBox(height: 14),
                  _Line(widthFactor: 0.72),
                  const SizedBox(height: 8),
                  _Line(widthFactor: 0.52),
                  const SizedBox(height: 8),
                  _Line(widthFactor: 0.64),
                  const SizedBox(height: 8),
                  _Line(widthFactor: 0.48),
                  const SizedBox(height: 8),
                  _Line(widthFactor: 0.60),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: tagColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$qualityLabel âœ“',
                  style: TextStyle(
                    color: tagColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniDocumentIcon extends StatelessWidget {
  const MiniDocumentIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 66,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(widthFactor: 1, height: 5),
          SizedBox(height: 5),
          _Line(widthFactor: 0.8, height: 5),
          SizedBox(height: 5),
          _Line(widthFactor: 0.95, height: 5),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.widthFactor,
    this.height = 5,
    this.color = Colors.black45,
  });

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
