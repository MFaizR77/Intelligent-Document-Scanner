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
import 'package:tugasbesar_pcd/config/pcd_params.dart';
import 'package:tugasbesar_pcd/models/scan_artifact.dart';
import 'package:tugasbesar_pcd/models/scan_result.dart';
import 'package:tugasbesar_pcd/services/image_processing/document_pipeline.dart';
import 'package:tugasbesar_pcd/services/image_processing/enhancement.dart';
import 'package:tugasbesar_pcd/services/ocr/text_recognition_service.dart';
import 'package:tugasbesar_pcd/services/storage/file_service.dart';
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
  late ScanArtifact _artifact;
  late EnhancementMode _mode;
  ScanResult? _saved;
  bool _saving = false;
  bool _ocrLoading = false;
  bool _switchingMode = false;
  String? _exportedPdfPath;

  @override
  void initState() {
    super.initState();
    _artifact = widget.artifact;
    _mode = _modeFromLabel(widget.artifact.enhancementMode);
  }

  EnhancementMode _modeFromLabel(String label) {
    for (final m in EnhancementMode.values) {
      if (m.label == label) return m;
    }
    return EnhancementMode.color;
  }

  /// Re-run enhancement saja (deteksi & warp memakai 4 sudut yang sudah
  /// tersimpan di artifact saat ini), lalu update path enhanced.
  Future<void> _switchMode(EnhancementMode mode) async {
    if (_switchingMode || mode == _mode) return;
    setState(() => _switchingMode = true);

    final oldEnhancedPath = _artifact.enhancedPath;
    try {
      final newPath = await FileService.newEnhancedJpegPath();
      final profile =
          PcdParams.profileForLabel(_artifact.documentPlanLabel);
      final updated = await DocumentPipeline.runFromFile(
        inputPath: _artifact.originalPath,
        outputPath: newPath,
        profile: profile,
        mode: mode,
        overrideCorners: _artifact.cornersImage,
      );
      if (!mounted) return;
      setState(() {
        _artifact = updated;
        _mode = mode;
        // Reset state save: hasil baru belum tersimpan ke Hive.
        _saved = null;
      });
      // Best-effort hapus file mode lama supaya tidak menumpuk.
      try {
        final oldFile = File(oldEnhancedPath);
        if (await oldFile.exists()) await oldFile.delete();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ganti mode: $e')),
      );
    } finally {
      if (mounted) setState(() => _switchingMode = false);
    }
  }

  Future<void> _save() async {
    if (_saved != null || _saving) return;
    setState(() => _saving = true);
    try {
      final entry = await ScanRepository.instance.save(_artifact);
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
    final TextEditingController nameController = TextEditingController(
      text: '${_artifact.documentPlanLabel}_${DateTime.now().millisecondsSinceEpoch}',
    );

    final customName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Simpan PDF', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nama File',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('Simpan', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (customName == null || customName.trim().isEmpty) return;
    final finalName = customName.trim();

    try {
      final path = await PdfExportService.instance.exportImages(
        [_artifact.enhancedPath],
        hint: _artifact.documentPlanLabel,
        exactName: finalName,
      );
      if (!mounted) return;
      setState(() => _exportedPdfPath = path);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'Hasil scan $finalName',
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
        [XFile(_artifact.enhancedPath)],
        text: 'Scan ${_artifact.documentPlanLabel}',
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
      final result = await svc.recognize(File(_artifact.enhancedPath));
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
    final a = _artifact;
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        BeforeAfterSlider(
                          // Key dengan path memastikan widget rebuild penuh
                          // saat enhancedPath berganti (mode di-switch).
                          key: ValueKey(a.enhancedPath),
                          beforePath: a.originalPath,
                          afterPath: a.enhancedPath,
                        ),
                        if (_switchingMode)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black54,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
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

          // Mode selector (4 mode dari EnhancementService).
          _ModeSelector(
            current: _mode,
            disabled: _switchingMode,
            onSelect: _switchMode,
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

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.current,
    required this.onSelect,
    required this.disabled,
  });

  final EnhancementMode current;
  final ValueChanged<EnhancementMode> onSelect;
  final bool disabled;

  // 4 mode dari EnhancementService — urutan match dengan order yang familiar
  // di app sejenis (Color → BW → Grayscale → Magic).
  static const _items = <(EnhancementMode, String, IconData)>[
    (EnhancementMode.color, 'Color', Icons.palette_outlined),
    (EnhancementMode.bw, 'B&W', Icons.contrast),
    (EnhancementMode.grayscale, 'Grayscale', Icons.filter_b_and_w),
    (EnhancementMode.magic, 'Magic', Icons.auto_awesome),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Text(
                  'Mode Enhancement',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.swipe,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
          // Horizontal scroll: hindari layout sempit kalau nanti ada mode
          // tambahan, dan kasih tap target yang lebih lega per chip.
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              physics: const BouncingScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final item = _items[i];
                return _ModeChip(
                  label: item.$2,
                  icon: item.$3,
                  active: current == item.$1,
                  disabled: disabled,
                  onTap: () => onSelect(item.$1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = active ? AppColors.primary : Colors.white60;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: disabled && !active ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 86,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: tint, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tint,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
