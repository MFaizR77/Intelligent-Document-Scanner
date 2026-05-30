// lib/views/history/scan_detail_screen.dart
//
// Detail untuk satu entry ScanResult dari Hive.
// Re-use OCR / share / export PDF di sini juga.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/models/scan_result.dart';
import 'package:tugasbesar_pcd/services/ocr/text_recognition_service.dart';
import 'package:tugasbesar_pcd/services/storage/pdf_export_service.dart';
import 'package:tugasbesar_pcd/services/storage/scan_repository.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

class ScanDetailScreen extends StatefulWidget {
  const ScanDetailScreen({super.key, required this.result});

  final ScanResult result;

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  bool _ocrLoading = false;

  String _formatDateTime(DateTime d) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}/${d.year} ${pad(d.hour)}:${pad(d.minute)}';
  }

  String _humanFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _runOcr() async {
    if (_ocrLoading) return;
    setState(() => _ocrLoading = true);
    final svc = TextRecognitionService();
    try {
      // OCR halaman pertama saja.
      final result = await svc.recognize(File(widget.result.pages.first));
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
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            children: [
              const Text(
                'Hasil OCR',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: SelectableText(
                    result.isEmpty ? '(Tidak ada teks)' : result.fullText,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppPrimaryButton(
                label: 'Salin',
                icon: Icons.copy,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: result.fullText),
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Disalin')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final TextEditingController nameController = TextEditingController(
      text: '${widget.result.displayTitle}_${DateTime.now().millisecondsSinceEpoch}',
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
        widget.result.pages,
        hint: widget.result.documentType,
        exactName: finalName,
      );
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path)],
        text: finalName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Hapus scan?'),
        content: const Text('File hasil dan entry riwayat akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Hapus semua file halaman (best-effort).
    for (final p in widget.result.pages) {
      try {
        final f = File(p);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    await ScanRepository.instance.delete(widget.result);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final pages = r.pages;
    int size = 0;
    try {
      // Ukuran total semua halaman.
      for (final p in pages) {
        final f = File(p);
        if (f.existsSync()) size += f.lengthSync();
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          r.displayTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: _PageViewer(pages: pages),
          ),
          const SizedBox(height: 20),
          _MetaRow(label: 'Nama dokumen', value: r.displayTitle),
          _MetaRow(label: 'Tipe dokumen', value: r.documentType),
          if (pages.length > 1)
            _MetaRow(label: 'Jumlah halaman', value: '${pages.length}'),
          _MetaRow(label: 'Tanggal scan', value: _formatDateTime(r.scanDate)),
          _MetaRow(
            label: 'Confidence',
            value:
                '${(r.confidenceScore * 100).clamp(0, 100).toStringAsFixed(0)}%',
            valueColor: AppColors.primary,
          ),
          _MetaRow(label: 'Ukuran file', value: _humanFileSize(size)),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: _ocrLoading ? 'OCR berjalan...' : 'Ekstrak Teks (OCR)',
            icon: Icons.text_snippet_outlined,
            onPressed: _ocrLoading ? () {} : _runOcr,
          ),
          const SizedBox(height: 10),
          AppPrimaryButton(
            label: 'Export PDF',
            icon: Icons.picture_as_pdf,
            backgroundColor: AppColors.surface,
            foregroundColor: Colors.white70,
            onPressed: _exportPdf,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Penampil halaman dokumen. Single-page → satu gambar; multi-page → PageView
/// horizontal dengan indikator halaman.
class _PageViewer extends StatefulWidget {
  const _PageViewer({required this.pages});

  final List<String> pages;

  @override
  State<_PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends State<_PageViewer> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildImage(String path) {
    final file = File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: file.existsSync()
          ? Image.file(file, fit: BoxFit.cover, gaplessPlayback: true)
          : Container(
              color: AppColors.elevated,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.white24),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.length == 1) {
      return SizedBox.expand(child: _buildImage(widget.pages.first));
    }
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _buildImage(widget.pages[i]),
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_index + 1}/${widget.pages.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
