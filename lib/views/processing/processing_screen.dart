import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/widgets/document/document_preview_card.dart';

class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Memproses Dokumen',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(28),
        children: const [
          Row(
            children: [
              Expanded(
                child: DocumentPreviewCard(
                  qualityLabel: 'Original',
                  tagColor: Colors.grey,
                ),
              ),
              SizedBox(width: 0),
              Expanded(
                child: DocumentPreviewCard(
                  qualityLabel: 'Enhanced',
                  tagColor: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 28),
          _StepTile(
            label: 'Grayscale + Gaussian Blur',
            time: '12ms',
            done: true,
          ),
          _StepTile(label: 'Canny Edge Detection', time: '28ms', done: true),
          _StepTile(label: 'Perspective Correction', time: '45ms', done: true),
          _StepTile(label: 'Shadow Removal...', active: true),
          _StepTile(label: 'TFLite Classification'),
          _StepTile(label: 'Contrast Enhancement'),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.label,
    this.time,
    this.done = false,
    this.active = false,
  });

  final String label;
  final String? time;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active
            ? AppColors.blue.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? AppColors.blue.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: done
                ? AppColors.primary
                : active
                ? AppColors.blue
                : AppColors.elevated,
            child: done
                ? const Icon(Icons.check, color: Colors.black, size: 18)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: done || active ? Colors.white : Colors.white30,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          if (time != null)
            Text(
              time!,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}
