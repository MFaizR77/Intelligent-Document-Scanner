// lib/views/processing/scan_result_screen.dart
//
// Layar hasil scan: tampilkan before/after slider, action bar (OCR, save,
// export PDF, share). OCR dipanggil on-demand pada gambar enhanced (PCD murni
// di hulu, ML hanya post-processor).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/models/scan_artifact.dart';
import 'package:tugasbesar_pcd/models/scan_result.dart';
import 'package:tugasbesar_pcd/services/ocr/text_recognition_service.dart';
import 'package:tugasbesar_pcd/services/storage/pdf_export_service.dart';
import 'package:tugasbesar_pcd/services/storage/scan_repository.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';
import 'package:tugasbesar_pcd/widgets/document/before_after_slider.dart';

class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({super.key, required this.artifact});

  final ScanArtifact artifact;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  ScanResult? _saved;
  bool _saving = false;
  bool _ocrLoading = false;
  String? _exportedPdfPath;

  Future<void> _save() async {
    if (_saved != null || _saving) return;
    setState(() => _saving = true);
    try {
      final entry = await ScanRepository.instance.save(widget.artifact);
      if (!mounted) return;
      setState(() => _saved = entry);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tersimpan ke Riwayat')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    try {
      final path = await PdfExportService.instance.exportImages(
        [widget.artifact.enhancedPath],
        hint: widget.artifact.documentPlanLabel,
      );
      if (!mounted) return;
      setState(() => _exportedPdfPath = path);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'Hasil scan ${widget.artifact.documentPlanLabel}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export PDF: $e')),
      );
    }
  }

  Future<void> _shareImage() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.artifact.enhancedPath)],
        text: 'Scan ${widget.artifact.documentPlanLabel}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal bagikan: $e')),
      );
    }
  }

  Future<void> _runOcr() async {
    if (_ocrLoading) return;
    setState(() => _ocrLoading = true);
    final svc = TextRecognitionService();
    try {
      final result = await svc.recognize(File(widget.artifact.enhancedPath));
      if (!mounted) return;
      _showOcrSheet(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR gagal: $e')),
      );
    } finally {
      await svc.dispose();
      if (mounted) setState(() => _ocrLoading = false);
    }
  }

  void _showOcrSheet(OcrResult result) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Hasil OCR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${result.latency.inMilliseconds} ms',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SingleChildScrollView(
                        controller: controller,
                        child: SelectableText(
                          result.isEmpty
                              ? '(Tidak ada teks terdeteksi)'
                              : result.fullText,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Salin',
                          icon: Icons.copy,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: result.fullText),
                            );
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Teks disalin')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Bagikan',
                          icon: Icons.ios_share,
                          backgroundColor: AppColors.elevated,
                          foregroundColor: Colors.white70,
                          onPressed: () async {
                            await Share.share(result.fullText);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.artifact;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        centerTitle: true,
        title: const Text(
          'Hasil Scan',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // Before / After
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BeforeAfterSlider(
                      beforePath: a.originalPath,
                      afterPath: a.enhancedPath,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Metric(label: 'Mode', value: a.enhancementMode),
                    _Metric(
                      label: 'Plan',
                      value: a.documentPlanLabel,
                      color: AppColors.primary,
                    ),
                    _Metric(
                      label: 'Sharp',
                      value: a.blurScore.toStringAsFixed(0),
                    ),
                    _Metric(
                      label: 'Pipeline',
                      value: '${a.totalDuration.inMilliseconds} ms',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AppPrimaryButton(
            label: _ocrLoading ? 'Mengekstrak...' : 'Ekstrak Teks (OCR)',
            icon: Icons.text_snippet_outlined,
            onPressed: _ocrLoading ? () {} : _runOcr,
          ),
          const SizedBox(height: 10),
          AppPrimaryButton(
            label: 'Export & Bagikan PDF',
            icon: Icons.picture_as_pdf,
            backgroundColor: AppColors.surface,
            foregroundColor: Colors.white70,
            onPressed: _exportPdf,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: 'Bagikan JPG',
                  icon: Icons.image_outlined,
                  backgroundColor: AppColors.surface,
                  foregroundColor: Colors.white70,
                  onPressed: _shareImage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppPrimaryButton(
                  label: _saving
                      ? 'Menyimpan...'
                      : (_saved != null ? 'Tersimpan' : 'Simpan'),
                  icon: _saved != null
                      ? Icons.check
                      : Icons.save_outlined,
                  backgroundColor: _saved != null
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : AppColors.surface,
                  foregroundColor:
                      _saved != null ? AppColors.primary : Colors.white70,
                  onPressed: _save,
                ),
              ),
            ],
          ),
          if (_exportedPdfPath != null) ...[
            const SizedBox(height: 10),
            Text(
              'PDF: $_exportedPdfPath',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
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
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
