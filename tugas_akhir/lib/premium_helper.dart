import 'package:hive_flutter/hive_flutter.dart';

class PremiumHelper {
  // Nama box khusus untuk data premium
  static const String _boxName = 'premium_data';

  // 🔹 Wajib dipanggil di main.dart agar box terbuka
  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  // 🔹 Aktifkan premium untuk email tertentu
  static Future<void> activatePremium(String email, int months) async {
    final box = Hive.box(_boxName);
    
    DateTime expireDate;
    
    // Cek apakah user ini sudah punya premium aktif sebelumnya
    // Jika iya, perpanjang dari tanggal expired terakhir
    if (isPremiumActive(email)) {
      final String? currentExpireStr = box.get('expire_$email');
      if (currentExpireStr != null) {
        final currentExpire = DateTime.parse(currentExpireStr);
        expireDate = DateTime(
          currentExpire.year, 
          currentExpire.month + months, 
          currentExpire.day,
          currentExpire.hour,
          currentExpire.minute,
        );
      } else {
        // Fallback jika data tanggal korup
        final now = DateTime.now();
        expireDate = DateTime(now.year, now.month + months, now.day);
      }
    } else {
      // Jika baru beli atau sudah expired sebelumnya, mulai dari sekarang
      final now = DateTime.now();
      expireDate = DateTime(now.year, now.month + months, now.day);
    }

    // Simpan status dan tanggal expired dengan kunci unik email
    await box.put('premium_$email', true);
    await box.put('expire_$email', expireDate.toIso8601String());
  }

  // 🔹 Cek status premium berdasarkan email
  // Return bool langsung (sinkronus) biar gampang dipakai di UI
  static bool isPremiumActive(String? email) {
    if (email == null || email.isEmpty) return false;
    
    // Pastikan box terbuka
    if (!Hive.isBoxOpen(_boxName)) return false;

    final box = Hive.box(_boxName);
    final bool isPremium = box.get('premium_$email', defaultValue: false);
    final String? expireStr = box.get('expire_$email');

    if (!isPremium || expireStr == null) return false;

    final expireDate = DateTime.parse(expireStr);
    final now = DateTime.now();

    // Jika sekarang sudah melewati tanggal expired -> matikan premium
    if (now.isAfter(expireDate)) {
      // Kita biarkan status di DB true, tapi return false.
      // Opsional: Bisa di-update ke false di DB jika mau bersih-bersih data.
      return false;
    }

    return true;
  }

  // 🔹 Ambil tanggal expired (Opsional: untuk ditampilkan di Profile nanti)
  static DateTime? getExpireDate(String email) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    final String? expireStr = box.get('expire_$email');
    
    if (expireStr != null) {
      return DateTime.parse(expireStr);
    }
    return null;
  }
}