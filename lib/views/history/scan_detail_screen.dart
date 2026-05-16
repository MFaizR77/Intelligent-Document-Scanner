import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/models/ui_scan_document.dart';
import 'package:tugasbesar_pcd/views/processing/scan_result_screen.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';
import 'package:tugasbesar_pcd/widgets/document/document_preview_card.dart';

class ScanDetailScreen extends StatelessWidget {
  const ScanDetailScreen({super.key, required this.document});

  final UiScanDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          document.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(Icons.chevron_left),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
        children: [
          Center(
            child: SizedBox(
              width: 210,
              child: DocumentPreviewCard(
                qualityLabel: '${document.quality}%',
                large: true,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _MetaRow(label: 'Nama file', value: document.fileName),
          _MetaRow(label: 'Tanggal scan', value: document.date),
          _MetaRow(label: 'Tipe dokumen', value: document.type),
          _MetaRow(
            label: 'Confidence',
            value: '${document.quality}% sharp',
            valueColor: AppColors.primary,
          ),
          _MetaRow(label: 'Ukuran file', value: document.size),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: 'Export',
                  icon: Icons.download,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ScanResultScreen(document: document),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Bagikan',
                  icon: Icons.ios_share,
                  backgroundColor: AppColors.elevated,
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
