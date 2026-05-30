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

  /// Nama dokumen yang diberi user saat menyimpan. Null untuk data lama;
  /// UI fallback ke [documentType] bila kosong.
  @HiveField(4)
  final String? title;

  /// Semua halaman dokumen (path JPG enhanced), urut. Untuk dokumen
  /// single-page, ini berisi satu path yang sama dengan [imagePath].
  /// Null untuk data lama (diperlakukan sebagai single-page [imagePath]).
  @HiveField(5)
  final List<String>? pagePaths;

  ScanResult({
    required this.imagePath,
    required this.scanDate,
    required this.documentType,
    required this.confidenceScore,
    this.title,
    this.pagePaths,
  });

  /// Judul tampilan: [title] kalau ada, kalau tidak fallback ke tipe dokumen.
  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty) ? title!.trim() : documentType;

  /// Daftar halaman efektif: [pagePaths] kalau ada & tidak kosong, kalau tidak
  /// perlakukan [imagePath] sebagai satu-satunya halaman.
  List<String> get pages =>
      (pagePaths != null && pagePaths!.isNotEmpty) ? pagePaths! : [imagePath];

  int get pageCount => pages.length;
}
