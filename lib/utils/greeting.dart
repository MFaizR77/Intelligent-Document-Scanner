// lib/utils/greeting.dart
//
// Sapaan dinamis berdasarkan jam lokal.

/// Mengembalikan sapaan berdasarkan [hour] (0–23).
///   04–10 → "Selamat pagi"
///   11–14 → "Selamat siang"
///   15–18 → "Selamat sore"
///   selain itu → "Selamat malam"
String greetingForHour(int hour) {
  if (hour >= 4 && hour < 11) return 'Selamat pagi';
  if (hour >= 11 && hour < 15) return 'Selamat siang';
  if (hour >= 15 && hour < 19) return 'Selamat sore';
  return 'Selamat malam';
}

/// Sapaan untuk waktu sekarang.
String greetingNow([DateTime? now]) =>
    greetingForHour((now ?? DateTime.now()).hour);
