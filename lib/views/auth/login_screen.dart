import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/views/home/home_shell.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

/// Login screen — offline mode (Hive only). Tidak ada autentikasi server,
/// jadi screen ini cuma intro card + tombol "Mulai" yang langsung ke home.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _enterApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const _BrandHeader(),
              const SizedBox(height: 56),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Selamat\n'),
                    TextSpan(
                      text: 'datang kembali.',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 33,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Aplikasi berjalan offline. Semua scan disimpan di perangkat '
                'lewat Hive — tidak butuh akun, tidak butuh internet.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              const _FeatureRow(
                icon: Icons.bolt_outlined,
                text: 'Edge detection realtime di kamera',
              ),
              const SizedBox(height: 14),
              const _FeatureRow(
                icon: Icons.layers_outlined,
                text: 'Pipeline PCD: warp, shadow removal, enhancement',
              ),
              const SizedBox(height: 14),
              const _FeatureRow(
                icon: Icons.lock_outline,
                text: 'Penyimpanan lokal — privasi sepenuhnya di tangan kamu',
              ),
              const Spacer(),
              AppPrimaryButton(
                label: 'Mulai',
                icon: Icons.arrow_forward,
                onPressed: () => _enterApp(context),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Versi 0.1 · Tugas Besar PCD',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.article, color: Colors.black87),
        ),
        const SizedBox(width: 12),
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
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
