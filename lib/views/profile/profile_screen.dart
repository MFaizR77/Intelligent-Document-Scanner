import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            _ProfileHero(),
            Padding(
              padding: EdgeInsets.fromLTRB(28, 28, 28, 0),
              child: Row(
                children: [
                  _StatCard(value: '24', label: 'Scan'),
                  SizedBox(width: 12),
                  _StatCard(value: '18', label: 'PDF'),
                  SizedBox(width: 12),
                  _StatCard(value: '96%', label: 'Quality'),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(28, 22, 28, 0),
              child: _SyncCard(),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: _LogoutButton(),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(28, 30, 28, 0),
              child: _SettingsPanel(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 246,
      padding: const EdgeInsets.fromLTRB(28, 82, 28, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF063719), AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black, width: 3),
            ),
            alignment: Alignment.center,
            child: const Text(
              'F',
              style: TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Muhammad Faiz',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const Text(
            'TIF24001 · Polban',
            style: TextStyle(color: Colors.white60, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_outlined, color: AppColors.primary),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sync aktif',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Terakhir: 09 Mei 2026, 09:40',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.52)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout, color: AppColors.danger),
          SizedBox(width: 10),
          Text(
            'Keluar dari Akun',
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SectionLabel('Kualitas Scan'),
        _SettingTile(
          icon: Icons.wb_sunny_outlined,
          title: 'Resolusi Output',
          value: '300 DPI',
          color: AppColors.primary,
        ),
        _SettingTile(
          icon: Icons.layers_outlined,
          title: 'TFLite Model',
          value: 'v2.1',
          color: AppColors.blue,
        ),
        _SettingTile(
          icon: Icons.remove_red_eye_outlined,
          title: 'Blur Threshold',
          value: '85',
          color: AppColors.warning,
        ),
        SizedBox(height: 22),
        SectionLabel('Preferensi'),
        _SwitchTile(
          icon: Icons.camera_alt_outlined,
          title: 'Auto-Capture',
          enabled: true,
        ),
        _SwitchTile(
          icon: Icons.flash_auto,
          title: 'Flash Otomatis',
          enabled: false,
        ),
        _SwitchTile(
          icon: Icons.notifications_none,
          title: 'Haptic Feedback',
          enabled: true,
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white30),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.elevated,
            child: Icon(icon, color: Colors.white54),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: null,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
