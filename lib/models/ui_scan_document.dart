class UiScanDocument {
  const UiScanDocument({
    required this.title,
    required this.fileName,
    required this.date,
    required this.type,
    required this.quality,
    required this.size,
    required this.extension,
  });

  final String title;
  final String fileName;
  final String date;
  final String type;
  final int quality;
  final String size;
  final String extension;
}

const sampleScanDocuments = <UiScanDocument>[
  UiScanDocument(
    title: 'Laporan PCD',
    fileName: 'laporan_pcd.pdf',
    date: '09 Mei 2026',
    type: 'Kertas A4',
    quality: 97,
    size: '1.2 MB',
    extension: 'PDF',
  ),
  UiScanDocument(
    title: 'Struk Belanja',
    fileName: 'Struk_Belanja.jpg',
    date: '08 Mei 2026',
    type: 'Struk',
    quality: 82,
    size: '820 KB',
    extension: 'JPG',
  ),
  UiScanDocument(
    title: 'Catatan Kuliah',
    fileName: 'Catatan_Kuliah.pdf',
    date: '07 Mei 2026',
    type: 'Dokumen',
    quality: 94,
    size: '640 KB',
    extension: 'PDF',
  ),
  UiScanDocument(
    title: 'KTP Teman',
    fileName: 'ktp_teman.pdf',
    date: '05 Mei 2026',
    type: 'KTP',
    quality: 88,
    size: '420 KB',
    extension: 'PDF',
  ),
];
