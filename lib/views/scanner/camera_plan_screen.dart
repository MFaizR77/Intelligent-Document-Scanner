import 'package:flutter/material.dart';

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

  static const List<String> _plans = <String>[
    'A4',
    'Receipt',
    'ID Card',
    'Handwritten',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPlan = _plans.contains(widget.currentPlan)
        ? widget.currentPlan
        : 'A4';
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
      appBar: AppBar(title: const Text('Camera Plan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih rencana scan dokumen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _plans
                  .map(
                    (plan) => ChoiceChip(
                      label: Text(plan),
                      selected: _selectedPlan == plan,
                      onSelected: (_) {
                        setState(() {
                          _selectedPlan = plan;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              value: _autoCaptureEnabled,
              title: const Text('Auto-capture'),
              subtitle: const Text('Capture otomatis saat dokumen stabil.'),
              onChanged: (value) {
                setState(() {
                  _autoCaptureEnabled = value;
                });
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Simpan Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
