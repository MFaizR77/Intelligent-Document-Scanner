import 'package:flutter/material.dart';
import 'package:tugasbesar_pcd/views/onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    // Untuk saat ini, selalu tampilkan Onboarding (sesuai permintaan testing)
    // final settingsBox = Hive.box('settings');
    // final hasSeenOnboarding = settingsBox.get('hasSeenOnboarding', defaultValue: false);
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1210),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34C759).withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.document_scanner, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'DocScanner',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SMART DOCUMENT DIGITIZER',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(0),
                _buildDot(1),
                _buildDot(2),
                _buildDot(3),
              ],
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF34C759).withValues(alpha: index == 0 ? 1.0 : 0.4),
        shape: BoxShape.circle,
      ),
    );
  }
}
