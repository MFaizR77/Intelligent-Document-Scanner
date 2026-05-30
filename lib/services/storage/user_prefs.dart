// lib/services/storage/user_prefs.dart
//
// Wrapper tipis di atas Hive box `settings` (sudah dibuka di main.dart) untuk
// menyimpan preferensi user lokal — tanpa server, tanpa akun. Saat ini hanya
// menyimpan nama user yang dipakai di Beranda & Profile.

import 'package:hive/hive.dart';

class UserPrefs {
  UserPrefs._();

  static const String _boxName = 'settings';
  static const String _keyUserName = 'userName';
  static const String _keyHasSeenOnboarding = 'hasSeenOnboarding';

  static Box get _box => Hive.box(_boxName);

  /// Nama user tersimpan, atau null kalau belum pernah diisi.
  static String? get userName {
    final raw = _box.get(_keyUserName);
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  /// True kalau user sudah pernah mengisi nama.
  static bool get hasUserName => userName != null;

  static Future<void> setUserName(String name) async {
    await _box.put(_keyUserName, name.trim());
  }

  static Future<void> clearUserName() async {
    await _box.delete(_keyUserName);
  }

  /// Inisial untuk avatar (maks 2 huruf), mis. "Muhammad Faiz" → "MF".
  /// Fallback "?" kalau nama kosong.
  static String initialsOf(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.first.substring(0, 1);
    final last = parts.last.substring(0, 1);
    return '$first$last'.toUpperCase();
  }

  // Onboarding flag (dipakai bersama OnboardingScreen).
  static bool get hasSeenOnboarding =>
      _box.get(_keyHasSeenOnboarding, defaultValue: false) as bool;

  static Future<void> setHasSeenOnboarding(bool value) async {
    await _box.put(_keyHasSeenOnboarding, value);
  }
}
