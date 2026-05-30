// lib/views/processing/scan_result_screen.dart
//
// Editor hasil scan multi-halaman (ala CamScanner):
//   - strip thumbnail halaman: pilih, hapus, reorder (drag), foto ulang
//   - tambah halaman (kamera PCD / ML Kit / galeri) → pipeline yang sama
//   - before/after slider + ganti mode enhancement per halaman aktif
//   - simpan ke Riwayat (dengan nama dokumen) → 1 ScanResult multi-halaman
//   - export PDF multi-halaman + share
//   - OCR (halaman pertama saja) — PCD murni di hulu, ML hanya post-processor

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/config/pcd_params.dart';
import 'package:tugasbesar_pcd/controllers/document_session.dart';
import 'package:tugasbesar_pcd/models/scan_artifact.dart';
import 'package:tugasbesar_pcd/models/scan_engine.dart';
import 'package:tugasbesar_pcd/models/scan_result.dart';
import 'package:tugasbesar_pcd/services/image_processing/document_pipeline.dart';
import 'package:tugasbesar_pcd/services/image_processing/enhancement.dart';
import 'package:tugasbesar_pcd/services/ocr/text_recognition_service.dart';
import 'package:tugasbesar_pcd/services/storage/file_service.dart';
import 'package:tugasbesar_pcd/services/storage/pdf_export_service.dart';
import 'package:tugasbesar_pcd/services/storage/scan_repository.dart';
import 'package:tugasbesar_pcd/views/scanner/page_capture_flow.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';
import 'package:tugasbesar_pcd/widgets/document/before_after_slider.dart';

class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({super.key, required this.artifact});

  final ScanArtifact artifact;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  late final DocumentSession _session;
  EnhancementMode _mode = EnhancementMode.color;
  ScanResult? _saved;
  bool _saving = false;
  bool _ocrLoading = false;
  bool _switchingMode = false;
  bool _addingPage = false;

  @override
  void initState() {
    super.initState();
    _session = DocumentSession(widget.artifact);
    _mode = _modeFromLabel(widget.artifact.enhancementMode);
    _session.addListener(_onSession);
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _session.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    // Sinkronkan mode chip dengan halaman aktif & invalidasi status simpan.
    setState(() {
      _mode = _modeFromLabel(_session.active.enhancementMode);
    });
  }

  ScanArtifact get _artifact => _session.active;

  EnhancementMode _modeFromLabel(String label) {
    for (final m in EnhancementMode.values) {
      if (m.label == label) return m;
    }
    return EnhancementMode.color;
  }

  /// Re-run enhancement pada halaman aktif (warp pakai 4 sudut tersimpan).
  Future<void> _switchMode(EnhancementMode mode) async {
    if (_switchingMode || mode == _mode) return;
    setState(() => _switchingMode = true);

    final current = _session.active;
    final oldEnhancedPath = current.enhancedPath;
    try {
      final newPath = await FileService.newEnhancedJpegPath();
      final profile = PcdParams.profileForLabel(current.documentPlanLabel);
      final updated = await DocumentPipeline.runFromFile(
        inputPath: current.originalPath,
        outputPath: newPath,
        profile: profile,
        mode: mode,
        overrideCorners: current.cornersImage,
        skipGeometry: current.engine.skipGeometry,
        engine: current.engine,
      );
      if (!mounted) return;
      _session.replaceActive(updated);
      setState(() {
        _mode = mode;
        _saved = null; // hasil baru belum tersimpan.
      });
      // Best-effort hapus file mode lama.
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

  // ---------------- Multi-page: tambah / foto ulang halaman ----------------

  Future<void> _addPage() async {
    if (_addingPage) return;
    setState(() => _addingPage = true);
    try {
      final artifact = await PageCaptureFlow.captureOne(
        context,
        documentPlan: _session.active.documentPlanLabel,
      );
      if (artifact == null || !mounted) return;
      _session.addPage(artifact);
      setState(() => _saved = null);
    } finally {
      if (mounted) setState(() => _addingPage = false);
    }
  }

  Future<void> _rephotoPage(int index) async {
    if (_addingPage) return;
    setState(() => _addingPage = true);
    try {
      final artifact = await PageCaptureFlow.captureOne(
        context,
        documentPlan: _session.active.documentPlanLabel,
      );
      if (artifact == null || !mounted) return;
      _session.replaceAt(index, artifact);
      setState(() => _saved = null);
    } finally {
      if (mounted) setState(() => _addingPage = false);
    }
  }

  void _deletePage(int index) {
    if (_session.pageCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dokumen minimal punya 1 halaman')),
      );
      return;
    }
    _session.removeAt(index);
    setState(() => _saved = null);
  }

  // ---------------- Simpan / Export / Share / OCR ----------------

  Future<void> _save() async {
    if (_saved != null || _saving) return;

    final title = await _askDocumentName(
      title: 'Simpan ke Riwayat',
      initial: _defaultDocName(),
    );
    if (title == null) return; // batal

    setState(() => _saving = true);
    try {
      final entry = await ScanRepository.instance.savePages(
        pages: _session.toDocumentPages(),
        documentType: _session.active.documentPlanLabel,
        blurScore: _session.active.blurScore,
        title: title,
      );
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
    final finalName = await _askDocumentName(
      title: 'Export PDF',
      initial: _defaultDocName(),
    );
    if (finalName == null) return;

    try {
      final path = await PdfExportService.instance.exportImages(
        _session.enhancedPaths,
        hint: _session.active.documentPlanLabel,
        exactName: finalName,
      );
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Hasil scan $finalName (${_session.pageCount} halaman)',
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
        _session.enhancedPaths.map((p) => XFile(p)).toList(),
        text: 'Scan ${_session.active.documentPlanLabel}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal bagikan: $e')),
      );
    }
  }

  String _defaultDocName() =>
      '${_session.active.documentPlanLabel}_${DateTime.now().millisecondsSinceEpoch}';

  Future<String?> _askDocumentName({
    required String title,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama Dokumen',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child:
                const Text('Simpan', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (result == null) return null;
    final trimmed = result.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _runOcr() async {
    if (_ocrLoading) return;
    setState(() => _ocrLoading = true);
    final svc = TextRecognitionService();
    String? tempOcrPath;
    try {
      // OCR halaman pertama. ML Kit OCR membaca paling akurat pada citra
      // ber-kontras tinggi (teks hitam, latar putih). Mode tampilan bisa saja
      // Color/Magic yang kurang optimal untuk OCR, jadi kita siapkan versi
      // B&W khusus dari halaman pertama hanya untuk OCR.
      final first = _session.pages.first;
      tempOcrPath = await _buildOcrOptimizedImage(first);
      final target = tempOcrPath ?? first.enhancedPath;
      final result = await svc.recognize(File(target));
      if (!mounted) return;
      _showOcrSheet(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR gagal: $e')),
      );
    } finally {
      await svc.dispose();
      // Bersihkan file OCR sementara.
      if (tempOcrPath != null) {
        try {
          final f = File(tempOcrPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _ocrLoading = false);
    }
  }

  /// Bangun citra B&W (binarized) dari [page] khusus untuk OCR. Re-run pipeline
  /// dengan mode B&W pada gambar asli halaman tsb. Mengembalikan path file
  /// sementara, atau null kalau gagal (caller fallback ke gambar enhanced).
  Future<String?> _buildOcrOptimizedImage(ScanArtifact page) async {
    try {
      // Kalau mode aktif sudah B&W, gambar enhanced sudah optimal untuk OCR.
      if (page.enhancementMode == EnhancementMode.bw.label) return null;
      final outPath = await FileService.newEnhancedJpegPath();
      final profile = PcdParams.profileForLabel(page.documentPlanLabel);
      final artifact = await DocumentPipeline.runFromFile(
        inputPath: page.originalPath,
        outputPath: outPath,
        profile: profile,
        mode: EnhancementMode.bw,
        overrideCorners: page.cornersImage,
        skipGeometry: page.engine.skipGeometry,
        engine: page.engine,
      );
      return artifact.enhancedPath;
    } catch (_) {
      return null;
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
                          'Hasil OCR (halaman 1)',
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
        title: Text(
          _session.isMultiPage
              ? 'Hasil Scan · ${_session.pageCount} halaman'
              : 'Hasil Scan',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // Before / After (halaman aktif)
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
                    _Metric(label: 'Engine', value: a.engine.label),
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
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Strip halaman (thumbnail + reorder + add).
          _PageStrip(
            session: _session,
            busy: _addingPage,
            onSelect: _session.setActive,
            onAdd: _addPage,
            onDelete: _deletePage,
            onRephoto: _rephotoPage,
            onReorder: (oldI, newI) {
              _session.reorder(oldI, newI);
              setState(() => _saved = null);
            },
          ),
          const SizedBox(height: 16),

          // Mode enhancement (halaman aktif).
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
                  icon: _saved != null ? Icons.check : Icons.save_outlined,
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
        ],
      ),
    );
  }
}

class _PageStrip extends StatelessWidget {
  const _PageStrip({
    required this.session,
    required this.busy,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
    required this.onRephoto,
    required this.onReorder,
  });

  final DocumentSession session;
  final bool busy;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onRephoto;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final pages = session.pages;
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
                  'Halaman (${pages.length})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (busy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                else
                  Text(
                    'tahan & geser untuk urutkan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 132,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: true,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: pages.length,
              onReorder: onReorder,
              footer: Padding(
                key: const ValueKey('add_page_btn'),
                padding: const EdgeInsets.only(left: 8),
                child: _AddPageButton(onTap: busy ? null : onAdd),
              ),
              itemBuilder: (context, i) {
                final page = pages[i];
                final active = i == session.activeIndex;
                return Padding(
                  key: ValueKey(page.enhancedPath),
                  padding: const EdgeInsets.only(right: 8),
                  child: _PageThumb(
                    index: i,
                    path: page.enhancedPath,
                    active: active,
                    onTap: () => onSelect(i),
                    onDelete: () => onDelete(i),
                    onRephoto: () => onRephoto(i),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PageThumb extends StatelessWidget {
  const _PageThumb({
    required this.index,
    required this.path,
    required this.active,
    required this.onTap,
    required this.onDelete,
    required this.onRephoto,
  });

  final int index;
  final String path;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRephoto;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: active ? AppColors.primary : AppColors.border,
                            width: active ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                  // Nomor halaman.
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  // Menu (foto ulang / hapus).
                  Positioned(
                    right: 0,
                    top: 0,
                    child: PopupMenuButton<String>(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      color: AppColors.elevated,
                      icon: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.more_vert,
                            color: Colors.white, size: 16),
                      ),
                      onSelected: (v) {
                        if (v == 'rephoto') onRephoto();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rephoto',
                          child: Row(
                            children: [
                              Icon(Icons.refresh, size: 18, color: Colors.white70),
                              SizedBox(width: 8),
                              Text('Foto ulang'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.danger),
                              SizedBox(width: 8),
                              Text('Hapus'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPageButton extends StatelessWidget {
  const _AddPageButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
            width: 1.4,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
            SizedBox(height: 8),
            Text(
              'Tambah\nHalaman',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              physics: const BouncingScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
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
