// lib/views/profile/profile_screen.dart
//
// Profil mode OFFLINE: tidak ada akun/sync server. Menampilkan nama user
// (tersimpan lokal via UserPrefs), statistik nyata dari Hive, dan aksi
// edit nama + hapus semua riwayat.

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/models/scan_result.dart';
import 'package:tugasbesar_pcd/services/storage/scan_repository.dart';
import 'package:tugasbesar_pcd/services/storage/user_prefs.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editName() async {
    final controller = TextEditingController(text: UserPrefs.userName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Nama', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nama',
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
    await UserPrefs.setUserName(newName);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Hapus semua riwayat?'),
        content: const Text(
          'Semua entry riwayat akan dihapus permanen. File hasil scan tidak '
          'bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final count = await ScanRepository.instance.deleteAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count dokumen dihapus dari riwayat')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<Box<ScanResult>>(
          valueListenable: ScanRepository.instance.listenable(),
          builder: (context, box, _) {
            final scans = box.values.toList();
            final totalScans = scans.length;
            final totalPages =
                scans.fold<int>(0, (sum, s) => sum + s.pageCount);
            final avgQuality = totalScans > 0
                ? (scans
                            .map((s) => s.confidenceScore)
                            .reduce((a, b) => a + b) /
                        totalScans *
                        100)
                    .round()
                : 0;
            final name = UserPrefs.userName ?? 'Pengguna';

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _ProfileHero(name: name, onEdit: _editName),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                  child: Row(
                    children: [
                      _StatCard(value: '$totalScans', label: 'Dokumen'),
                      const SizedBox(width: 12),
                      _StatCard(value: '$totalPages', label: 'Halaman'),
                      const SizedBox(width: 12),
                      _StatCard(value: '$avgQuality%', label: 'Avg Quality'),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 22, 28, 0),
                  child: _OfflineCard(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                  child: _ActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit Nama',
                    color: AppColors.primary,
                    onTap: _editName,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                  child: _ActionButton(
                    icon: Icons.delete_sweep_outlined,
                    label: 'Hapus Semua Riwayat',
                    color: AppColors.danger,
                    onTap: _clearHistory,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 30, 28, 24),
                  child: _AboutPanel(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.name, required this.onEdit});

  final String name;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 246,
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                child: Text(
                  UserPrefs.initialsOf(name),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, color: Colors.white70),
                tooltip: 'Edit nama',
              ),
            ],
          ),
          const Spacer(),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Mode Offline · DocScanner',
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
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

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
          Icon(Icons.offline_bolt_outlined, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aplikasi berjalan offline',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Semua dokumen & data tersimpan di perangkat (Hive). '
                  'Tanpa akun, tanpa internet.',
                  style: TextStyle(color: Colors.white54, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SectionLabel('Tentang'),
        _InfoTile(
          icon: Icons.straighten,
          title: 'Resolusi pipeline',
          value: '≤ 2000 px',
          color: AppColors.primary,
        ),
        _InfoTile(
          icon: Icons.remove_red_eye_outlined,
          title: 'Threshold blur',
          value: '80',
          color: AppColors.warning,
        ),
        _InfoTile(
          icon: Icons.info_outline,
          title: 'Versi aplikasi',
          value: '0.1',
          color: AppColors.blue,
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
        ],
      ),
    );
  }
}
