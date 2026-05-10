import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/config/app_colors.dart';
import 'package:tugasbesar_pcd/widgets/common/app_components.dart';

class CameraPlanResult {
  const CameraPlanResult({
    required this.documentPlan,
    required this.autoCaptureEnabled,
  });

  final String documentPlan;
  final bool autoCaptureEnabled;
}

class CameraPlanScreen extends StatefulWidget {
  const CameraPlanScreen({
    super.key,
    required this.currentPlan,
    required this.currentAutoCapture,
  });

  final String currentPlan;
  final bool currentAutoCapture;

  @override
  State<CameraPlanScreen> createState() => _CameraPlanScreenState();
}

class _CameraPlanScreenState extends State<CameraPlanScreen> {
  late String _selectedPlan;
  late bool _autoCaptureEnabled;

  static const List<String> _plans = <String>['Auto', 'A4', 'Buku', 'KTP'];

  @override
  void initState() {
    super.initState();
    _selectedPlan = _plans.contains(widget.currentPlan)
        ? widget.currentPlan
        : 'Auto';
    _autoCaptureEnabled = widget.currentAutoCapture;
  }

  void _save() {
    Navigator.of(context).pop(
      CameraPlanResult(
        documentPlan: _selectedPlan,
        autoCaptureEnabled: _autoCaptureEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Pengaturan Scan',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SectionLabel('Mode Dokumen'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _plans.map((plan) {
              final selected = _selectedPlan == plan;
              return InkWell(
                onTap: () => setState(() => _selectedPlan = plan),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    plan,
                    style: TextStyle(
                      color: selected ? AppColors.primary : Colors.white60,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Preferensi'),
          _SwitchRow(
            icon: Icons.camera_alt_outlined,
            title: 'Auto-Capture',
            subtitle: 'Capture otomatis saat dokumen stabil.',
            value: _autoCaptureEnabled,
            onChanged: (value) => setState(() => _autoCaptureEnabled = value),
          ),
          const SizedBox(height: 12),
          const _InfoCard(),
          const SizedBox(height: 28),
          AppPrimaryButton(label: 'Simpan Plan', onPressed: _save),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.38)),
      ),
      child: const Row(
        children: [
          Icon(Icons.layers_outlined, color: AppColors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Phase 1-2: kamera, isolate, Canny edge, contour dokumen, perspective/enhancement baseline. ML dan Mongo end-to-end belum diaktifkan.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
