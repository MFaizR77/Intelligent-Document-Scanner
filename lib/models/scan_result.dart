// lib/models/scan_result.dart
import 'package:hive/hive.dart';

part 'scan_result.g.dart';

@HiveType(typeId: 0)
class ScanResult extends HiveObject {
  @HiveField(0)
  final String imagePath;

  @HiveField(1)
  final DateTime scanDate;

  @HiveField(2)
  final String documentType;

  @HiveField(3)
  final double confidenceScore;

  ScanResult({
    required this.imagePath,
    required this.scanDate,
    required this.documentType,
    required this.confidenceScore,
  });
}
