import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';

class ScannerStatusChip extends StatelessWidget {
  const ScannerStatusChip({
    super.key,
    required this.isReady,
    required this.statusText,
  });

  final bool isReady;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final color = isReady ? AppColors.primary : AppColors.warning;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.elevated.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 22),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 9, color: color),
            const SizedBox(width: 8),
            Text(
              isReady ? 'Dokumen terdeteksi' : statusText,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
