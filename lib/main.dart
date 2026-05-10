import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tugasbesar_pcd/models/scan_result.dart';
import 'package:tugasbesar_pcd/services/storage/mongo_service.dart';
import 'package:tugasbesar_pcd/views/scanner/scanner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage (Hive)
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  // Register Hive Adapters (Hakim's Task)
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ScanResultAdapter());
  }
  await Hive.openBox<ScanResult>('scan_results');

  // Initialize MongoDB (online) for Phase 1 baseline.
  // App keeps running even if MongoDB is not configured/reachable.
  try {
    await MongoService.instance.init();
  } catch (_) {
    // Ignore at startup; local flow should still work.
  }

  runApp(const MobileEdgeIntelligenceApp());
}

class MobileEdgeIntelligenceApp extends StatelessWidget {
  const MobileEdgeIntelligenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner Cerdas (PCD)',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ScannerScreen(),
    );
  }
}
