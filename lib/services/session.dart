import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 세션(휴대폰번호) 영구 저장.
class Session {
  static const _kPhone = 'phone';

  static Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPhone, phone);
  }

  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPhone);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPhone);
  }
}
