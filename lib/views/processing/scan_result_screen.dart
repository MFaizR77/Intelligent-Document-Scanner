import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/models/ui_scan_document.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';
import 'package:tugasbesar_pcd/widgets/document/document_preview_card.dart';

class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key, required this.document});

  final UiScanDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        centerTitle: true,
        title: const Text(
          'Hasil Scan',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(Icons.chevron_left),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 190,
                  child: DocumentPreviewCard(
                    qualityLabel: 'Tajam',
                    large: true,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  height: 70,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      _Metric(label: 'Tipe', value: document.type),
                      _Metric(
                        label: 'Kualitas',
                        value: '${document.quality}%',
                        color: AppColors.primary,
                      ),
                      _Metric(label: 'Ukuran', value: document.size),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppPrimaryButton(
            label: 'Export sebagai PDF',
            icon: Icons.download,
            onPressed: () {},
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: 'Bagikan',
                  icon: Icons.ios_share,
                  backgroundColor: AppColors.surface,
                  foregroundColor: Colors.white70,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Simpan',
                  icon: Icons.save_outlined,
                  backgroundColor: AppColors.surface,
                  foregroundColor: Colors.white70,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
