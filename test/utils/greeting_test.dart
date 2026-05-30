import 'package:flutter_test/flutter_test.dart';
import 'package:tugasbesar_pcd/utils/greeting.dart';

void main() {
  group('Greeting Utils Tests', () {
    test('greetingForHour mengembalikan sapaan yang benar berdasarkan jam', () {
      // 04-10 -> Pagi
      expect(greetingForHour(4), 'Selamat pagi');
      expect(greetingForHour(10), 'Selamat pagi');
      
      // 11-14 -> Siang
      expect(greetingForHour(11), 'Selamat siang');
      expect(greetingForHour(14), 'Selamat siang');
      
      // 15-18 -> Sore
      expect(greetingForHour(15), 'Selamat sore');
      expect(greetingForHour(18), 'Selamat sore');
      
      // 19-03 -> Malam
      expect(greetingForHour(19), 'Selamat malam');
      expect(greetingForHour(23), 'Selamat malam');
      expect(greetingForHour(0), 'Selamat malam');
      expect(greetingForHour(3), 'Selamat malam');
    });

    test('greetingNow mengembalikan sapaan berdasarkan waktu spesifik yang diberikan', () {
      final pagi = DateTime(2023, 1, 1, 8); // Jam 8 Pagi
      expect(greetingNow(pagi), 'Selamat pagi');

      final malam = DateTime(2023, 1, 1, 21); // Jam 9 Malam
      expect(greetingNow(malam), 'Selamat malam');
    });
  });
}
