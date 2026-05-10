import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';
import 'package:tugasbesar_pcd/widgets/document/document_preview_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          children: [
            const SizedBox(height: 40),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(
                          Icons.article,
                          color: Colors.black87,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Doc'),
                            TextSpan(
                              text: 'Scanner',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'SMART DOCUMENT DIGITIZER',
                        style: TextStyle(
                          color: AppColors.primary,
                          letterSpacing: 2.8,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44),
            const _PageDots(active: 0),
            const SizedBox(height: 38),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Scan '),
                  TextSpan(
                    text: 'cerdas,',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  TextSpan(text: '\nhasil sempurna.'),
                ],
              ),
              style: TextStyle(
                fontSize: 31,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Deteksi dokumen otomatis dengan Computer Vision. Tidak perlu crop manual lagi.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 30),
            Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -0.1,
                  child: Container(
                    width: 180,
                    height: 260,
                    decoration: BoxDecoration(
                      color: const Color(0xFF211D19),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 190,
                  child: DocumentPreviewCard(qualityLabel: '', large: true),
                ),
              ],
            ),
            const SizedBox(height: 30),
            AppPrimaryButton(label: 'Mulai Sekarang ✦', onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (index) {
        return Container(
          width: index == active ? 42 : 24,
          height: 6,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: index == active ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}
