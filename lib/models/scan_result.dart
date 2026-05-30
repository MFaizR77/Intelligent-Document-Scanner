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

  /// Path gambar RAW (sebelum enhance) per halaman, sejajar dengan
  /// [pagePaths]. Disimpan supaya image processing (ganti mode enhancement)
  /// bisa di-rerun lossless dari sumber. Null untuk data lama.
  @HiveField(6)
  final List<String>? originalPaths;

  /// Corner per halaman dalam koordinat RAW, di-encode CSV
  /// "x1,y1,x2,y2,x3,y3,x4,y4". String kosong = full-frame / tidak ada.
  @HiveField(7)
  final List<String>? pageCorners;

  /// Engine per halaman: "pcd" / "mlkit". Menentukan skipGeometry saat rerun.
  @HiveField(8)
  final List<String>? pageEngines;

  /// Mode enhancement aktif per halaman (label: Color/B&W/Grayscale/Magic).
  @HiveField(9)
  final List<String>? pageModes;

  ScanResult({
    required this.imagePath,
    required this.scanDate,
    required this.documentType,
    required this.confidenceScore,
    this.title,
    this.pagePaths,
    this.originalPaths,
    this.pageCorners,
    this.pageEngines,
    this.pageModes,
  });

  /// Judul tampilan: [title] kalau ada, kalau tidak fallback ke tipe dokumen.
  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty) ? title!.trim() : documentType;

  /// Daftar halaman efektif: [pagePaths] kalau ada & tidak kosong, kalau tidak
  /// perlakukan [imagePath] sebagai satu-satunya halaman.
  List<String> get pages =>
      (pagePaths != null && pagePaths!.isNotEmpty) ? pagePaths! : [imagePath];

  int get pageCount => pages.length;

  /// True bila metadata per-halaman lengkap (bisa rerun image processing
  /// dari sumber raw). Data lama mengembalikan false.
  bool get hasEditableMeta =>
      originalPaths != null && originalPaths!.length == pages.length;
}

