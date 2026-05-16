import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tugasbesar_pcd/views/auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _onNext() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _onBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() async {
    final settingsBox = Hive.box('settings');
    await settingsBox.put('hasSeenOnboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1210), // Dark background
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildPage(
                  0,
                  _buildIllustration1(),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(text: 'Scan '),
                        TextSpan(
                          text: 'cerdas',
                          style: TextStyle(color: Color(0xFF34C759), fontStyle: FontStyle.italic),
                        ),
                        TextSpan(text: ',\n'),
                        TextSpan(text: 'hasil sempurna.'),
                      ],
                    ),
                  ),
                  'Deteksi dokumen otomatis dengan Computer Vision. Tidak perlu crop manual lagi.',
                ),
                _buildPage(
                  1,
                  _buildIllustration2(),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(text: 'Pipeline PCD\n'),
                        TextSpan(
                          text: 'otomatis.',
                          style: TextStyle(color: Color(0xFF34C759), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  'Gaussian blur, Homography, Shadow removal — semua berjalan di Background Isolate.',
                ),
                _buildPage(
                  2,
                  _buildIllustration3(),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(text: 'Simpan &\n'),
                        TextSpan(
                          text: 'bagikan mudah.',
                          style: TextStyle(color: Color(0xFFF5A623), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  'Export ke PDF, simpan lokal via Hive, atau sinkronisasi ke cloud kapanpun.',
                ),
              ],
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int pageIndex, Widget illustration, Widget title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: illustration,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final activeColor = index == 2 ? const Color(0xFFF5A623) : const Color(0xFF34C759);
              return Container(
                margin: const EdgeInsets.only(right: 8),
                width: pageIndex == index ? 24 : 8,
                height: 4,
                decoration: BoxDecoration(
                  color: pageIndex == index ? activeColor : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          title,
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildIllustration1() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(-20, -20),
          child: Transform.rotate(
            angle: -0.1,
            child: Container(
              width: 200,
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF1E211F),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Container(
          width: 200,
          height: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F0E6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 12, width: 120, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Container(height: 8, width: double.infinity, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Container(height: 8, width: 100, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Container(height: 8, width: 140, color: Colors.grey.shade300),
            ],
          ),
        ),
        Container(
          width: 220,
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF34C759), width: 3),
          ),
          child: Stack(
            children: [
              Positioned(top: 0, left: 0, child: Container(width: 16, height: 16, color: const Color(0xFF34C759))),
              Positioned(top: 0, right: 0, child: Container(width: 16, height: 16, color: const Color(0xFF34C759))),
              Positioned(bottom: 0, left: 0, child: Container(width: 16, height: 16, color: const Color(0xFF34C759))),
              Positioned(bottom: 0, right: 0, child: Container(width: 16, height: 16, color: const Color(0xFF34C759))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIllustration2() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPipelineItem('Gaussian Blur', '12ms', true, true),
        const SizedBox(height: 16),
        _buildPipelineItem('Canny Edge', '28ms', true, true),
        const SizedBox(height: 16),
        _buildPipelineItem('Shadow Removal...', '', false, true, isActive: true),
        const SizedBox(height: 16),
        _buildPipelineItem('TFLite Classify', '', false, false),
      ],
    );
  }

  Widget _buildPipelineItem(String title, String time, bool isDone, bool isEnabled, {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1E2825) : const Color(0xFF1A1F1D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF34C759) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : (isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            color: isDone ? const Color(0xFF34C759) : (isActive ? const Color(0xFF34C759) : Colors.grey.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isEnabled ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
          if (time.isNotEmpty)
            Text(
              time,
              style: const TextStyle(
                color: Color(0xFF34C759),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIllustration3() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFileItem('Laporan_PCD.pdf', '1.2 MB', '97%', 'PDF', const Color(0xFF34C759)),
        const SizedBox(height: 16),
        _buildFileItem('Struk_Belanja.jpg', '820 KB', '82%', 'JPG', const Color(0xFFF5A623)),
        const SizedBox(height: 16),
        _buildFileItem('Catatan_Kuliah.pdf', '640 KB', '94%', 'PDF', const Color(0xFF34C759)),
      ],
    );
  }

  Widget _buildFileItem(String name, String size, String confidence, String type, Color tagColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0E6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.description, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$size  ·  $confidence',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              type,
              style: TextStyle(
                color: tagColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final bool isLastPage = _currentPage == 2;
    
    return Positioned(
      bottom: 48,
      left: 24,
      right: 24,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isLastPage
            ? SizedBox(
                key: const ValueKey('start_btn'),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _finishOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Mulai Sekarang ✦',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              )
            : Row(
                key: const ValueKey('nav_btns'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _currentPage == 0 ? _finishOnboarding : _onBack,
                    child: Text(
                      _currentPage == 0 ? 'Lewati' : '← Kembali',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34C759),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Lanjut →',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D1210),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
