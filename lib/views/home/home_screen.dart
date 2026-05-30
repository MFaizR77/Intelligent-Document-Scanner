import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/models/scan_result.dart';
import 'package:tugasbesar_pcd/services/storage/user_prefs.dart';
import 'package:tugasbesar_pcd/utils/greeting.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key, 
    required this.onScanPressed,
    required this.onViewAllPressed,
  });

  final VoidCallback onScanPressed;
  final VoidCallback onViewAllPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<Box<ScanResult>>(
          valueListenable: Hive.box<ScanResult>('scan_results').listenable(),
          builder: (context, box, _) {
            final scans = box.values.toList();
            scans.sort((a, b) => b.scanDate.compareTo(a.scanDate));

            final totalScans = scans.length;
            final now = DateTime.now();
            final todayScans = scans.where((s) => 
                s.scanDate.year == now.year && 
                s.scanDate.month == now.month && 
                s.scanDate.day == now.day).length;

            final avgQuality = totalScans > 0 
                ? (scans.map((s) => s.confidenceScore).reduce((a, b) => a + b) / totalScans * 100).round()
                : 0;

            final recentScans = scans.take(3).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildMainActionCard(),
                  const SizedBox(height: 24),
                  _buildStatsRow(totalScans, todayScans, avgQuality),
                  const SizedBox(height: 32),
                  _buildRecentHeader(),
                  const SizedBox(height: 16),
                  _buildRecentList(recentScans),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final greeting = greetingNow();
    final name = UserPrefs.userName ?? 'Pengguna';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$name ',
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                    const TextSpan(
                      text: '✦',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainActionCard() {
    return GestureDetector(
      onTap: onScanPressed,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.background,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scan Dokumen\nBaru',
                    style: TextStyle(
                      color: AppColors.background,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Auto-detect ·\nPerspective fix',
                    style: TextStyle(
                      color: AppColors.background.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.background,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int totalScans, int todayScans, int avgQuality) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(totalScans.toString(), 'total\nscan', isGreen: true)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(todayScans.toString(), 'hari ini', isGreen: false)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('$avgQuality%', 'avg\nquality', isGreen: false)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, {required bool isGreen}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface.withValues(alpha: 0.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isGreen ? AppColors.primary : Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppColors.muted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Terbaru',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onViewAllPressed,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Lihat semua',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentList(List<ScanResult> recentScans) {
    if (recentScans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'Belum ada dokumen yang di-scan.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      );
    }
    
    return Column(
      children: recentScans.map((scan) {
        final now = DateTime.now();
        final isToday = scan.scanDate.year == now.year && 
                        scan.scanDate.month == now.month && 
                        scan.scanDate.day == now.day;
        final timeStr = '${scan.scanDate.hour.toString().padLeft(2, '0')}:${scan.scanDate.minute.toString().padLeft(2, '0')}';
        final subtitle = isToday ? 'Hari ini · $timeStr' : '${scan.scanDate.day}/${scan.scanDate.month}/${scan.scanDate.year} · $timeStr';
        
        final qualityPercent = (scan.confidenceScore * 100).round();
        final qualityColor = qualityPercent >= 90 ? AppColors.primary 
            : (qualityPercent >= 70 ? AppColors.warning : AppColors.danger);
            
        final isStruk = scan.documentType.toLowerCase().contains('struk');
        
        // Coba ekstrak nama dari path atau gunakan tipe dokumen
        final title = scan.documentType.isNotEmpty ? 'Scan ${scan.documentType}' : 'Dokumen Scan';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRecentItem(
            title,
            subtitle,
            '$qualityPercent%',
            qualityColor,
            isStruk: isStruk,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentItem(String title, String subtitle, String quality, Color qualityColor, {bool isStruk = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(4),
            ),
            child: isStruk 
            ? Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Container(height: 4, width: 28, color: Colors.grey.shade400, margin: const EdgeInsets.only(bottom: 4)),
                Container(height: 2, width: 28, color: Colors.grey.shade400),
              ],
            )
            : Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Container(height: 3, width: 28, color: Colors.grey.shade400, margin: const EdgeInsets.only(bottom: 5)),
                Container(height: 3, width: 28, color: Colors.grey.shade400, margin: const EdgeInsets.only(bottom: 5)),
                Container(height: 3, width: 28, color: Colors.grey.shade400, margin: const EdgeInsets.only(bottom: 5)),
                Container(height: 3, width: 20, color: Colors.grey.shade400),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: qualityColor.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              quality,
              style: TextStyle(
                color: qualityColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
