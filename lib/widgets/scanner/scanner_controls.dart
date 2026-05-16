import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

class ScannerControls extends StatelessWidget {
  const ScannerControls({
    super.key,
    required this.isReady,
    required this.autoCaptureEnabled,
    required this.plan,
    required this.flashEnabled,
    required this.onFlash,
    required this.onCapture,
    required this.onPlan,
  });

  final bool isReady;
  final bool autoCaptureEnabled;
  final String plan;
  final bool flashEnabled;
  final VoidCallback onFlash;
  final VoidCallback onCapture;
  final VoidCallback onPlan;

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
          _PlanChips(activePlan: plan, onPlan: onPlan),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isReady)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 16),
                ),
              Text(
                isReady
                    ? 'Tahan stabil · auto-capture dalam 1 detik'
                    : 'Miringkan kamera untuk meluruskan dokumen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isReady ? Colors.white54 : AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
              AppIconButton(icon: Icons.history, onPressed: onPlan),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanChips extends StatelessWidget {
  const _PlanChips({required this.activePlan, required this.onPlan});

  final String activePlan;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    const plans = ['Auto', 'A4', 'Buku', 'KTP'];
    return Wrap(
      spacing: 10,
      children: plans.map((plan) {
        final active = activePlan == plan;
        return InkWell(
          onTap: onPlan,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : Colors.black45,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              plan,
              style: TextStyle(
                color: active ? AppColors.primary : Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
