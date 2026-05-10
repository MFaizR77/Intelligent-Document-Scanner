import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tugasbesar_pcd/controllers/camera_controller.dart';
import 'package:tugasbesar_pcd/views/scanner/camera_plan_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  int _tabIndex = 0;
  bool _onboardingDone = false;

  final AppCameraController _cameraController = AppCameraController();

  bool _isLoadingCamera = false;
  bool _isCameraReady = false;
  bool _permissionDenied = false;
  String _statusText = 'Tekan Mulai Scan untuk membuka kamera';

  String _documentPlan = 'A4';
  bool _autoCaptureEnabled = true;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _initializeCameraFlow() async {
    if (_isLoadingCamera) {
      return;
    }

    setState(() {
      _isLoadingCamera = true;
      _permissionDenied = false;
      _statusText = 'Meminta izin kamera...';
    });

    final permission = await Permission.camera.request();
    if (!mounted) {
      return;
    }

    if (!permission.isGranted) {
      setState(() {
        _isLoadingCamera = false;
        _isCameraReady = false;
        _permissionDenied = true;
        _statusText = 'Izin kamera diperlukan untuk memindai dokumen.';
      });
      return;
    }

    try {
      await _cameraController.initialize();
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCamera = false;
        _isCameraReady = _cameraController.isInitialized;
        _permissionDenied = false;
        _statusText = 'Kamera belakang aktif - dokumen siap dipindai';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCamera = false;
        _isCameraReady = false;
        _permissionDenied = false;
        _statusText = 'Gagal inisialisasi kamera: $error';
      });
    }
  }

  Future<void> _openCameraPlan() async {
    if (!_isCameraReady) {
      await _initializeCameraFlow();
      if (!_isCameraReady || !mounted) {
        return;
      }
    }

    final result = await Navigator.of(context).push<CameraPlanResult>(
      MaterialPageRoute<CameraPlanResult>(
        builder: (_) => CameraPlanScreen(
          currentPlan: _documentPlan,
          currentAutoCapture: _autoCaptureEnabled,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _documentPlan = result.documentPlan;
      _autoCaptureEnabled = result.autoCaptureEnabled;
      _statusText = 'Plan aktif: $_documentPlan';
    });
  }

  Widget _buildCameraLayer() {
    final CameraController? controller = _cameraController.controller;
    if (_isCameraReady && controller != null) {
      return CameraPreview(controller);
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, color: Colors.white54, size: 48),
          SizedBox(height: 10),
          Text('Kamera belum aktif', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildPermissionOverlay() {
    if (!_permissionDenied) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Izin kamera belum diberikan.',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Izinkan kamera agar fitur scanner bisa digunakan.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _initializeCameraFlow,
              child: const Text('Coba lagi'),
            ),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Buka pengaturan aplikasi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerTab() {
    return Stack(
      children: [
        Positioned.fill(child: _buildCameraLayer()),
        if (_isLoadingCamera)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        _buildPermissionOverlay(),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x883DDC84)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.circle, size: 10, color: Color(0xFF3DDC84)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF3DDC84),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 28,
          child: Column(
            children: [
              Text(
                _autoCaptureEnabled
                    ? 'Tahan stabil - auto-capture aktif'
                    : 'Mode manual - auto-capture nonaktif',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundControlButton(icon: Icons.flash_auto, onTap: () {}),
                  GestureDetector(
                    onTap: _openCameraPlan,
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.6),
                      ),
                      child: Center(
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: Colors.black,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _RoundControlButton(icon: Icons.tune, onTap: _openCameraPlan),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _HistoryCard(
          title: 'Laporan Praktikum PCD',
          subtitle: '09 Mei 2026 · 09:41',
          confidence: '97% tajam',
        ),
        SizedBox(height: 10),
        _HistoryCard(
          title: 'Struk Pembelian Alat',
          subtitle: '08 Mei 2026 · 14:22',
          confidence: '82% tajam',
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profil Tim',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF141414),
            child: ListTile(
              title: const Text('Faiz (Ketua)'),
              subtitle: const Text('Lead Developer & Architecture - Phase 1'),
              trailing: const Icon(Icons.verified, color: Color(0xFF3DDC84)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        title: Text(
          _tabIndex == 0
              ? 'Scanner View'
              : _tabIndex == 1
              ? 'Riwayat Scan'
              : 'Profil',
        ),
        actions: _tabIndex == 0
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1F3DDC84),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _documentPlan,
                        style: const TextStyle(
                          color: Color(0xFF3DDC84),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: !_onboardingDone
          ? _OnboardingView(
              onStartPressed: () {
                setState(() {
                  _onboardingDone = true;
                  _tabIndex = 0;
                  _statusText = 'Tekan tombol tengah untuk buka Camera Plan';
                });
              },
            )
          : IndexedStack(
              index: _tabIndex,
              children: [
                _buildScannerTab(),
                _buildHistoryTab(),
                _buildProfileTab(),
              ],
            ),
      bottomNavigationBar: !_onboardingDone
          ? null
          : NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _tabIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.document_scanner_outlined),
                  selectedIcon: Icon(Icons.document_scanner),
                  label: 'Scan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'Riwayat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
      floatingActionButton: !_onboardingDone || _tabIndex != 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _initializeCameraFlow,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Mulai Scan'),
            ),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  const _OnboardingView({required this.onStartPressed});

  final VoidCallback onStartPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C0C0C), Color(0xFF171717)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mobile Edge Intelligence',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Scan dokumen realtime dengan pipeline PCD. Onboarding ini muncul dulu sebelum masuk scanner.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 26),
          const _OnboardingItem(
            icon: Icons.document_scanner,
            title: 'Scan Cerdas',
            subtitle: 'Kamera belakang + detect dokumen.',
          ),
          const SizedBox(height: 10),
          const _OnboardingItem(
            icon: Icons.auto_awesome,
            title: 'Auto Capture',
            subtitle: 'Capture saat dokumen stabil.',
          ),
          const SizedBox(height: 10),
          const _OnboardingItem(
            icon: Icons.history,
            title: 'Riwayat',
            subtitle: 'Semua scan tersimpan untuk review.',
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStartPressed,
              child: const Text('Lanjut ke Aplikasi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem extends StatelessWidget {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3DDC84)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1C1C1C),
          border: Border.all(color: const Color(0x44FFFFFF)),
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.title,
    required this.subtitle,
    required this.confidence,
  });

  final String title;
  final String subtitle;
  final String confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE8DF),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1F3DDC84),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    confidence,
                    style: const TextStyle(
                      color: Color(0xFF3DDC84),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.download, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
