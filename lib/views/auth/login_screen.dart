import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/services/storage/user_prefs.dart';
import 'package:tugasbesar_pcd/views/home/home_shell.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

/// Login screen — offline mode (Hive only). Tidak ada autentikasi server.
/// Screen ini meminta nama user (disimpan lokal via [UserPrefs]) lalu masuk
/// ke Home. Nama dipakai untuk sapaan di Beranda & identitas di Profile.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill kalau user sudah pernah mengisi nama.
    _nameController.text = UserPrefs.userName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _enterApp() async {
    final name = _nameController.text.trim();
    setState(() => _submitted = true);
    if (name.isEmpty) return;

    await UserPrefs.setUserName(name);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showError = _submitted && _nameController.text.trim().isEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 56,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const _BrandHeader(),
                  const SizedBox(height: 44),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Selamat\n'),
                        TextSpan(
                          text: 'datang.',
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
                  const SizedBox(height: 28),
                  const Text(
                    'Siapa nama kamu?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_submitted) setState(() {});
                    },
                    onSubmitted: (_) => _enterApp(),
                    decoration: InputDecoration(
                      hintText: 'mis. Muhammad Faiz',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon:
                          const Icon(Icons.person_outline, color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.surface,
                      errorText: showError ? 'Nama tidak boleh kosong' : null,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _FeatureRow(
                    icon: Icons.bolt_outlined,
                    text: 'Edge detection realtime di kamera',
                  ),
                  const SizedBox(height: 14),
                  const _FeatureRow(
                    icon: Icons.lock_outline,
                    text: 'Penyimpanan lokal — privasi sepenuhnya di tangan kamu',
                  ),
                  const Spacer(),
                  const SizedBox(height: 20),
                  AppPrimaryButton(
                    label: 'Mulai',
                    icon: Icons.arrow_forward,
                    onPressed: _enterApp,
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
