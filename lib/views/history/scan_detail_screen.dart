// lib/views/history/scan_detail_screen.dart
//
// Detail + EDITOR untuk satu entry ScanResult dari Hive.
// Mendukung: lihat semua halaman, edit nama dokumen, GANTI MODE ENHANCEMENT
// (image processing) per halaman, tambah halaman, foto ulang halaman, hapus
// halaman, reorder, lalu simpan perubahan kembali ke entry Hive yang sama.
// Plus OCR / export PDF / share / hapus dokumen.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/config/pcd_params.dart';
import 'package:tugasbesar_pcd/models/document_page.dart';
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

class ScanDetailScreen extends StatefulWidget {
  const ScanDetailScreen({super.key, required this.result});

  final ScanResult result;

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  bool _ocrLoading = false;
  bool _busy = false;
  bool _switchingMode = false;

  /// Working copy halaman & nama. Perubahan baru ditulis ke Hive saat Simpan.
  late List<DocumentPage> _pages;
  late String _title;
  int _activeIndex = 0;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _pages = _buildPages(widget.result);
    _title = widget.result.displayTitle;
  }

  /// Rekonstruksi [DocumentPage] dari ScanResult. Bila metadata per-halaman
  /// lengkap → bisa rerun lossless dari raw. Bila data lama → fallback:
  /// gambar enhanced dipakai sebagai sumber (reprocess di atas hasil enhance).
  List<DocumentPage> _buildPages(ScanResult r) {
    final enhanced = r.pages;
    final hasMeta = r.hasEditableMeta;
    return List.generate(enhanced.length, (i) {
      final originals = r.originalPaths;
      final corners = r.pageCorners;
      final engines = r.pageEngines;
      final modes = r.pageModes;
      return DocumentPage(
        enhancedPath: enhanced[i],
        originalPath: (hasMeta && originals != null) ? originals[i] : enhanced[i],
        corners: (corners != null && i < corners.length)
            ? DocumentPage.cornersFromCsv(corners[i])
            : const [],
        engine: (engines != null && i < engines.length)
            ? (engines[i] == 'mlkit' ? ScanEngine.mlkit : ScanEngine.pcd)
            : ScanEngine.pcd,
        mode: (modes != null && i < modes.length)
            ? modes[i]
            : EnhancementMode.color.label,
      );
    });
  }

  /// True kalau halaman [i] punya gambar raw terpisah (rerun lossless).
  bool _isLossless(int i) =>
      widget.result.hasEditableMeta &&
      _pages[i].originalPath != _pages[i].enhancedPath;

  DocumentPage get _active => _pages[_activeIndex];

  EnhancementMode _modeFromLabel(String label) {
    for (final m in EnhancementMode.values) {
      if (m.label == label) return m;
    }
    return EnhancementMode.color;
  }

  String _formatDateTime(DateTime d) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}/${d.year} ${pad(d.hour)}:${pad(d.minute)}';
  }

  String _humanFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  // ---------------- Image processing (ganti mode enhancement) ----------------

  Future<void> _switchMode(EnhancementMode mode) async {
    if (_switchingMode) return;
    final page = _active;
    if (mode.label == page.mode) return;
    setState(() => _switchingMode = true);

    final oldEnhanced = page.enhancedPath;
    final lossless = _isLossless(_activeIndex);
    try {
      final outPath = await FileService.newEnhancedJpegPath();
      final profile = PcdParams.profileForLabel(widget.result.documentType);
      final artifact = await DocumentPipeline.runFromFile(
        inputPath: page.originalPath,
        outputPath: outPath,
        profile: profile,
        mode: mode,
        // Lossless: pakai corners asli + engine asli (warp ulang dari raw).
        // Fallback: sumber = gambar enhanced yang sudah lurus → skip geometri.
        overrideCorners: lossless && page.corners.length == 4
            ? page.corners
            : null,
        skipGeometry: lossless ? page.engine.skipGeometry : true,
        engine: page.engine,
      );
      if (!mounted) return;
      setState(() {
        _pages[_activeIndex].enhancedPath = artifact.enhancedPath;
        _pages[_activeIndex].mode = mode.label;
        _dirty = true;
      });
      // Hapus file enhanced lama — TAPI jangan hapus kalau itu juga sumber
      // (kasus fallback data lama: originalPath == enhanced lama).
      if (oldEnhanced != page.originalPath) {
        _deleteFile(oldEnhanced);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ganti mode: $e')),
      );
    } finally {
      if (mounted) setState(() => _switchingMode = false);
    }
  }

  // ---------------- Editing nama / halaman ----------------

  Future<void> _editName() async {
    final controller = TextEditingController(text: _title);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Nama Dokumen',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
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
    if (newName == null || newName.trim().isEmpty) return;
    setState(() {
      _title = newName.trim();
      _dirty = true;
    });
  }

  Future<void> _addPage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final artifact = await PageCaptureFlow.captureOne(
        context,
        documentPlan: widget.result.documentType,
      );
      if (artifact == null || !mounted) return;
      setState(() {
        _pages.add(DocumentPage.fromArtifact(artifact));
        _activeIndex = _pages.length - 1;
        _dirty = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rephotoPage(int index) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final artifact = await PageCaptureFlow.captureOne(
        context,
        documentPlan: widget.result.documentType,
      );
      if (artifact == null || !mounted) return;
      final old = _pages[index].enhancedPath;
      final oldOriginal = _pages[index].originalPath;
      setState(() {
        _pages[index] = DocumentPage.fromArtifact(artifact);
        _dirty = true;
      });
      // Hapus file lama (enhanced & raw lama) bila tak dipakai halaman lain.
      if (!_pages.any((p) => p.enhancedPath == old)) _deleteFile(old);
      if (oldOriginal != old &&
          !_pages.any((p) => p.originalPath == oldOriginal)) {
        _deleteFile(oldOriginal);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _deletePage(int index) {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dokumen minimal punya 1 halaman')),
      );
      return;
    }
    final removed = _pages[index];
    setState(() {
      _pages.removeAt(index);
      if (_activeIndex >= _pages.length) _activeIndex = _pages.length - 1;
      _dirty = true;
    });
    if (!_pages.any((p) => p.enhancedPath == removed.enhancedPath)) {
      _deleteFile(removed.enhancedPath);
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    setState(() {
      final moved = _pages.removeAt(oldIndex);
      _pages.insert(target, moved);
      _activeIndex = target;
      _dirty = true;
    });
  }

  Future<void> _saveChanges() async {
    if (!_dirty || _busy) return;
    setState(() => _busy = true);
    try {
      await ScanRepository.instance.updatePages(
        widget.result,
        pages: _pages,
        title: _title,
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan tersimpan')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _deleteFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Simpan perubahan?'),
        content: const Text('Ada perubahan yang belum disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Buang'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child:
                const Text('Simpan', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (action == 'save') {
      await _saveChanges();
      return true;
    }
    return action == 'discard';
  }

  // ---------------- OCR / Export / Delete ----------------

  Future<void> _runOcr() async {
    if (_ocrLoading) return;
    setState(() => _ocrLoading = true);
    final svc = TextRecognitionService();
    String? tempOcrPath;
    try {
      final firstPage = _pages.first;
      tempOcrPath = await _buildOcrOptimizedImage(firstPage);
      final target = tempOcrPath ?? firstPage.enhancedPath;
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
      if (tempOcrPath != null) _deleteFile(tempOcrPath);
      if (mounted) setState(() => _ocrLoading = false);
    }
  }

  /// Citra B&W khusus OCR dari halaman pertama (sumber enhanced sudah lurus).
  Future<String?> _buildOcrOptimizedImage(DocumentPage page) async {
    try {
      if (page.mode == EnhancementMode.bw.label) return null;
      final outPath = await FileService.newEnhancedJpegPath();
      final profile = PcdParams.profileForLabel(widget.result.documentType);
      final artifact = await DocumentPipeline.runFromFile(
        inputPath: page.enhancedPath,
        outputPath: outPath,
        profile: profile,
        mode: EnhancementMode.bw,
        skipGeometry: true,
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
                'Hasil OCR (halaman 1)',
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
      text: '${_title}_${DateTime.now().millisecondsSinceEpoch}',
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
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary)),
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
            child:
                const Text('Simpan', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (customName == null || customName.trim().isEmpty) return;
    final finalName = customName.trim();

    try {
      final path = await PdfExportService.instance.exportImages(
        _pages.map((p) => p.enhancedPath).toList(),
        hint: widget.result.documentType,
        exactName: finalName,
      );
      if (!mounted) return;
      await Share.shareXFiles([XFile(path)], text: finalName);
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
    for (final p in _pages) {
      _deleteFile(p.enhancedPath);
    }
    await ScanRepository.instance.delete(widget.result);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    int size = 0;
    try {
      for (final p in _pages) {
        final f = File(p.enhancedPath);
        if (f.existsSync()) size += f.lengthSync();
      }
    } catch (_) {}

    final activeMode = _modeFromLabel(_active.mode);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await _confirmLeave();
        if (leave && mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(
            _title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Edit nama',
              onPressed: _editName,
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            ),
            IconButton(
              tooltip: 'Hapus dokumen',
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PageViewer(
                    key: ValueKey(_pages.map((p) => p.enhancedPath).join('|')),
                    pages: _pages.map((p) => p.enhancedPath).toList(),
                    initialIndex: _activeIndex,
                    onPageChanged: (i) => setState(() => _activeIndex = i),
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
            const SizedBox(height: 16),

            // Image processing: ganti mode enhancement untuk halaman aktif.
            _ModeSelector(
              current: activeMode,
              disabled: _switchingMode || _busy,
              onSelect: _switchMode,
            ),
            const SizedBox(height: 16),

            _PageEditorStrip(
              pages: _pages.map((p) => p.enhancedPath).toList(),
              activeIndex: _activeIndex,
              busy: _busy,
              onSelect: (i) => setState(() => _activeIndex = i),
              onAdd: _addPage,
              onDelete: _deletePage,
              onRephoto: _rephotoPage,
              onReorder: _reorder,
            ),
            const SizedBox(height: 18),
            _MetaRow(label: 'Nama dokumen', value: _title),
            _MetaRow(label: 'Tipe dokumen', value: r.documentType),
            _MetaRow(label: 'Mode halaman aktif', value: _active.mode),
            if (_pages.length > 1)
              _MetaRow(label: 'Jumlah halaman', value: '${_pages.length}'),
            _MetaRow(label: 'Tanggal scan', value: _formatDateTime(r.scanDate)),
            _MetaRow(
              label: 'Confidence',
              value:
                  '${(r.confidenceScore * 100).clamp(0, 100).toStringAsFixed(0)}%',
              valueColor: AppColors.primary,
            ),
            _MetaRow(label: 'Ukuran file', value: _humanFileSize(size)),
            const SizedBox(height: 16),
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppPrimaryButton(
                  label: _busy ? 'Menyimpan...' : 'Simpan Perubahan',
                  icon: Icons.save_outlined,
                  onPressed: _busy ? () {} : _saveChanges,
                ),
              ),
            AppPrimaryButton(
              label: _ocrLoading ? 'OCR berjalan...' : 'Ekstrak Teks (OCR)',
              icon: Icons.text_snippet_outlined,
              backgroundColor: AppColors.surface,
              foregroundColor: Colors.white70,
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

/// Selektor mode enhancement (image processing) — sama seperti di hasil scan.
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
            child: Text(
              'Mode Enhancement (Image Processing)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
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

/// Strip thumbnail halaman untuk editor: pilih (lihat), reorder (drag),
/// foto ulang, hapus, dan tambah halaman.
class _PageEditorStrip extends StatelessWidget {
  const _PageEditorStrip({
    required this.pages,
    required this.activeIndex,
    required this.busy,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
    required this.onRephoto,
    required this.onReorder,
  });

  final List<String> pages;
  final int activeIndex;
  final bool busy;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onRephoto;
  final void Function(int oldIndex, int newIndex) onReorder;

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
                return Padding(
                  key: ValueKey('page_${pages[i]}'),
                  padding: const EdgeInsets.only(right: 8),
                  child: _PageThumb(
                    index: i,
                    path: pages[i],
                    active: i == activeIndex,
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
    final file = File(path);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
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
                  child: file.existsSync()
                      ? Image.file(file, fit: BoxFit.cover, gaplessPlayback: true)
                      : const ColoredBox(
                          color: AppColors.elevated,
                          child: Center(
                            child:
                                Icon(Icons.broken_image, color: Colors.white24),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  child:
                      const Icon(Icons.more_vert, color: Colors.white, size: 16),
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

/// Penampil halaman dokumen. Single-page → satu gambar; multi-page → PageView
/// horizontal dengan indikator halaman.
class _PageViewer extends StatefulWidget {
  const _PageViewer({
    super.key,
    required this.pages,
    this.initialIndex = 0,
    this.onPageChanged,
  });

  final List<String> pages;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;

  @override
  State<_PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends State<_PageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.pages.length - 1);
    _controller = PageController(initialPage: _index);
  }

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
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onPageChanged?.call(i);
            },
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
