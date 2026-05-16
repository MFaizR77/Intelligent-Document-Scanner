import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/views/home/home_shell.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

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
              const SizedBox(height: 42),
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
              const SizedBox(height: 10),
              const Text(
                'Masuk untuk melanjutkan sesi scan-mu.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 34),
              const _AuthField(label: 'EMAIL', value: 'faiz@polban.ac.id'),
              const SizedBox(height: 20),
              const _AuthField(
                label: 'PASSWORD',
                value: '••••••••',
                obscure: true,
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Lupa password?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AppPrimaryButton(
                label: 'Masuk',
                onPressed: () => _enterApp(context),
              ),
              const SizedBox(height: 24),
              const _DividerText(),
              const SizedBox(height: 22),
              Row(
                children: const [
                  Expanded(
                    child: _SocialButton(label: 'Google', icon: 'G'),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _SocialButton(label: 'GitHub', icon: '●'),
                  ),
                ],
              ),
              const Spacer(),
              const Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Belum punya akun? ',
                    style: TextStyle(color: Colors.white38),
                    children: [
                      TextSpan(
                        text: 'Daftar gratis',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
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

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.value,
    this.obscure = false,
  });

  final String label;
  final String value;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            letterSpacing: 2.4,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: label == 'EMAIL'
                  ? AppColors.primary.withValues(alpha: 0.7)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (obscure)
                const Icon(
                  Icons.visibility_off_outlined,
                  color: Colors.white38,
                  size: 20,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DividerText extends StatelessWidget {
  const _DividerText();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('atau', style: TextStyle(color: Colors.white38)),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon});

  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: TextStyle(
              color: label == 'Google' ? Colors.redAccent : Colors.white70,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
