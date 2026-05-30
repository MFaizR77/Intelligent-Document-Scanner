// lib/views/history/history_screen.dart
//
// Daftar scan dari Hive (real-time via ValueListenableBuilder).
// Tap → ScanDetailScreen(result).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/models/scan_result.dart';
import 'package:tugasbesar_pcd/services/storage/scan_repository.dart';
import 'package:tugasbesar_pcd/views/history/scan_detail_screen.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'Semua';

  static const _filters = ['Semua', 'A4', 'Buku', 'KTP', 'Auto'];

  List<ScanResult> _applyFilter(List<ScanResult> all) {
    if (_filter == 'Semua') return all;
    return all
        .where((r) => r.documentType.toLowerCase() == _filter.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Riwayat',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  AppIconButton(icon: Icons.refresh, onPressed: () {
                    setState(() {});
                  }),
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                scrollDirection: Axis.horizontal,
                children: _filters.map((label) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _FilterChip(
                      label: label,
                      active: _filter == label,
                      onTap: () => setState(() => _filter = label),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<Box<ScanResult>>(
                valueListenable: ScanRepository.instance.listenable(),
                builder: (context, box, _) {
                  final list = box.values.toList()
                    ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
                  final filtered = _applyFilter(list);
                  if (filtered.isEmpty) {
                    return const _EmptyState();
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                        ),
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      return _HistoryGridCard(result: r);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: active ? AppColors.primary : Colors.white38),
        ),
      ),
    );
  }
}

class _HistoryGridCard extends StatelessWidget {
  const _HistoryGridCard({required this.result});

  final ScanResult result;

  String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$day/$m/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final file = File(result.imagePath);
    final exists = file.existsSync();
    final pct = (result.confidenceScore * 100).clamp(0, 100).toStringAsFixed(0);
    final pageCount = result.pageCount;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ScanDetailScreen(result: result),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(11),
                      ),
                      child: exists
                          ? Image.file(
                              file,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              gaplessPlayback: true,
                            )
                          : Container(
                              color: AppColors.elevated,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (pageCount > 1)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.copy_all,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '$pageCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDate(result.scanDate)}  •  $pct%',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 12),
            Text(
              'Belum ada scan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              'Mulai dari tab Scan untuk membuat dokumen baru.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
