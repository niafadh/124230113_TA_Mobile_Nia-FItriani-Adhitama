import 'package:shared_preferences/shared_preferences.dart';

class PremiumHelper {
  static const String keyIsPremium = 'is_premium';
  static const String keyExpireDate = 'premium_expire_date';

  // ✔ Aktifkan premium selama X bulan
  static Future<void> activatePremium(int months) async {
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final expire = DateTime(now.year, now.month + months, now.day);

    await prefs.setBool(keyIsPremium, true);
    await prefs.setString(keyExpireDate, expire.toIso8601String());
  }

  // ✔ Cek apakah premium masih berlaku
  static Future<bool> isPremiumActive() async {
    final prefs = await SharedPreferences.getInstance();

    final isPremium = prefs.getBool(keyIsPremium) ?? false;
    final expireStr = prefs.getString(keyExpireDate);

    if (!isPremium || expireStr == null) return false;

    final expireDate = DateTime.parse(expireStr);
    final now = DateTime.now();

    // Premium habis → matikan
    if (now.isAfter(expireDate)) {
      await prefs.setBool(keyIsPremium, false);
      return false;
    }

    return true;
  }
}
