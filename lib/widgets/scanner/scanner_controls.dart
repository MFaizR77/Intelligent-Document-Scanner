import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

class ScannerControls extends StatelessWidget {
  const ScannerControls({
    super.key,
    required this.isReady,
    required this.flashEnabled,
    required this.onFlash,
    required this.onCapture,
  });

  final bool isReady;
  final bool flashEnabled;
  final VoidCallback onFlash;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black87],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isReady
                ? 'Dokumen siap di-capture'
                : 'Miringkan kamera untuk meluruskan dokumen',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isReady ? Colors.white54 : AppColors.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppIconButton(
                icon: flashEnabled ? Icons.flash_on : Icons.flash_auto,
                onPressed: onFlash,
                active: flashEnabled,
              ),
              GestureDetector(
                onTap: onCapture,
                child: Container(
                  width: 86,
                  height: 86,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isReady ? AppColors.primary : AppColors.border,
                      width: 3,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isReady ? Colors.white : AppColors.elevated,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ],
      ),
    );
  }
}
