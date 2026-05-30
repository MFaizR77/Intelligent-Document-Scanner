import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tugasbesar_pcd/views/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreen merender teks dan icon dengan benar', (WidgetTester tester) async {
    // Build widget dalam MaterialApp
    await tester.pumpWidget(const MaterialApp(
      home: SplashScreen(),
    ));

    // Verifikasi keberadaan teks utama
    expect(find.text('DocScanner'), findsOneWidget);
    expect(find.text('SMART DOCUMENT DIGITIZER'), findsOneWidget);

    // Verifikasi keberadaan Icon document_scanner
    expect(find.byIcon(Icons.document_scanner), findsOneWidget);

    // Melewati delay 2 detik pada SplashScreen agar timer tidak "pending" saat test selesai
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
