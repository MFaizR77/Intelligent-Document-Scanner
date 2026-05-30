import 'package:flutter_test/flutter_test.dart';
import 'package:tugasbesar_pcd/models/scan_result.dart';

void main() {
  group('ScanResult Model Tests', () {
    test('displayTitle menggunakan title jika ada, sebaliknya documentType', () {
      final resultWithTitle = ScanResult(
        imagePath: 'path/to/image.jpg',
        scanDate: DateTime.now(),
        documentType: 'KTP',
        confidenceScore: 0.9,
        title: 'KTP Saya',
      );
      
      final resultWithoutTitle = ScanResult(
        imagePath: 'path/to/image.jpg',
        scanDate: DateTime.now(),
        documentType: 'KTP',
        confidenceScore: 0.9,
      );

      final resultWithEmptyTitle = ScanResult(
        imagePath: 'path/to/image.jpg',
        scanDate: DateTime.now(),
        documentType: 'KTP',
        confidenceScore: 0.9,
        title: '   ', // spasi kosong
      );

      expect(resultWithTitle.displayTitle, 'KTP Saya');
      expect(resultWithoutTitle.displayTitle, 'KTP');
      expect(resultWithEmptyTitle.displayTitle, 'KTP');
    });

    test('pages dan pageCount berfungsi dengan benar untuk single page dan multi page', () {
      // Data lama / Single page tanpa pagePaths
      final singlePageResult = ScanResult(
        imagePath: 'path/to/image.jpg',
        scanDate: DateTime.now(),
        documentType: 'KTP',
        confidenceScore: 0.9,
      );

      // Multi page
      final multiPageResult = ScanResult(
        imagePath: 'path/to/thumb.jpg', // thumbnail
        scanDate: DateTime.now(),
        documentType: 'Buku',
        confidenceScore: 0.8,
        pagePaths: ['path/to/page1.jpg', 'path/to/page2.jpg'],
      );

      expect(singlePageResult.pages, ['path/to/image.jpg']);
      expect(singlePageResult.pageCount, 1);

      expect(multiPageResult.pages, ['path/to/page1.jpg', 'path/to/page2.jpg']);
      expect(multiPageResult.pageCount, 2);
    });

    test('hasEditableMeta mengecek kelengkapan data originalPaths', () {
      // Data lama tanpa originalPaths
      final oldData = ScanResult(
        imagePath: 'path/to/image.jpg',
        scanDate: DateTime.now(),
        documentType: 'KTP',
        confidenceScore: 0.9,
      );

      // Data baru dengan originalPaths lengkap
      final newDataComplete = ScanResult(
        imagePath: 'thumb.jpg',
        scanDate: DateTime.now(),
        documentType: 'Doc',
        confidenceScore: 0.9,
        pagePaths: ['page1.jpg', 'page2.jpg'],
        originalPaths: ['raw1.jpg', 'raw2.jpg'],
      );

      // Data baru dengan originalPaths tidak lengkap (corrupt state)
      final newDataIncomplete = ScanResult(
        imagePath: 'thumb.jpg',
        scanDate: DateTime.now(),
        documentType: 'Doc',
        confidenceScore: 0.9,
        pagePaths: ['page1.jpg', 'page2.jpg'],
        originalPaths: ['raw1.jpg'],
      );

      expect(oldData.hasEditableMeta, isFalse);
      expect(newDataComplete.hasEditableMeta, isTrue);
      expect(newDataIncomplete.hasEditableMeta, isFalse);
    });
  });
}
