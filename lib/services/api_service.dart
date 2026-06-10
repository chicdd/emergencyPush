import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

/// .NET API 호출 래퍼.
class ApiService {
  static final Uri _base = Uri.parse(AppConfig.apiBaseUrl);

  static Uri _u(String path) => _base.replace(path: path);

  static const _jsonHeaders = {'Content-Type': 'application/json'};
  static const _timeout = Duration(seconds: 12);

  /// 로그아웃: 서버에서 FCM 토큰 제거 → 해당 기기로 푸시 발송 중단.
  static Future<bool> unregister(String phone, String? fcmToken) async {
    try {
      final res = await http
          .post(_u('/api/auth/unregister'),
              headers: _jsonHeaders,
              body: jsonEncode({'phone': phone, 'firebaseToken': fcmToken}))
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// 인증 화면: 휴대폰번호 + FCM 토큰 등록.
  static Future<bool> register(String phone, String? fcmToken) async {
    try {
      final res = await http
          .post(_u('/api/auth/register'),
              headers: _jsonHeaders,
              body: jsonEncode({'phone': phone, 'firebaseToken': fcmToken}))
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// 안드로이드 "메시지 파싱 대상" 저장(is_master=true).
  static Future<bool> setMaster(String id) async {
    try {
      final res = await http
          .post(_u('/api/device/master'),
              headers: _jsonHeaders, body: jsonEncode({'id': id}))
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// 등록된 모니터링 회선 목록(불러오기용).
  static Future<List<Map<String, dynamic>>> getConfigs() async {
    try {
      final res = await http.get(_u('/api/device/configs')).timeout(_timeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// 비상 상황 해제(상황 해제 / 상황 확인).
  static Future<bool> resolveEmergency(String? phone) async {
    try {
      final res = await http
          .post(_u('/api/emergency/resolve'),
              headers: _jsonHeaders, body: jsonEncode({'phone': phone}))
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// 현재 비상 상태 조회.
  static Future<bool> isEmergencyActive() async {
    try {
      final res = await http.get(_u('/api/emergency/status')).timeout(_timeout);
      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        return m['active'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// 서버 접속 가능 여부 확인.
  static Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(_u('/api/emergency/status'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// 서버에서 테스트 푸시를 1회 발송. 진단용 결과 문구를 반환.
  static Future<String> sendTestPush() async {
    try {
      final res = await http
          .post(_u('/api/push/test'), headers: _jsonHeaders)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = m['message']?.toString() ?? '요청 완료';
        final success = m['success'] ?? 0;
        final userCount = m['userCount'] ?? 0;
        final available = m['fcmAvailable'] == true;
        return '$msg (성공 $success/$userCount, FCM ${available ? "정상" : "비활성"})';
      }
      return '서버 오류 (${res.statusCode})';
    } catch (_) {
      return '서버 연결 실패';
    }
  }

  /// iOS 단축어가 호출할 ping URL(설정 화면에 표시/복사).
  static String pingUrl(String phone) => '${AppConfig.apiBaseUrl}/api/device/ping/$phone';
}
