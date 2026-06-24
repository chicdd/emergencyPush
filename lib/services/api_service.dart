import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class ApiService {
  static final Uri _base = Uri.parse(AppConfig.apiBaseUrl);

  static Uri _u(String path) => _base.replace(path: path);

  static const _jsonHeaders = {'Content-Type': 'application/json'};
  static const _timeout = Duration(seconds: 12);

  static Future<bool> unregister(String phone, String? fcmToken) async {
    try {
      final res = await http
          .post(
            _u('/api/auth/unregister'),
            headers: _jsonHeaders,
            body: jsonEncode({'phone': phone, 'firebaseToken': fcmToken}),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> register(String phone, String? fcmToken) async {
    try {
      final res = await http
          .post(
            _u('/api/auth/register'),
            headers: _jsonHeaders,
            body: jsonEncode({'phone': phone, 'firebaseToken': fcmToken}),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteAccount(String phone) async {
    try {
      final res = await http
          .post(
            _u('/api/auth/delete'),
            headers: _jsonHeaders,
            body: jsonEncode({'phone': phone}),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setMaster(String id) async {
    try {
      final res = await http
          .post(
            _u('/api/device/master'),
            headers: _jsonHeaders,
            body: jsonEncode({'id': id}),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

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

  static Future<bool> resolveEmergency(String? phone) async {
    try {
      final res = await http
          .post(
            _u('/api/emergency/resolve'),
            headers: _jsonHeaders,
            body: jsonEncode({'phone': phone}),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEmergencyActive() async {
    final m = await getStatus();
    return m?['active'] == true;
  }

  static Future<Map<String, dynamic>?> getStatus() async {
    try {
      final res = await http.get(_u('/api/emergency/status')).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> armStart(String? value) async {
    try {
      final res = await http
          .post(
            _u('/api/emergency/armstart'),
            headers: _jsonHeaders,
            body: jsonEncode({'value': value}),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

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

  static String pingUrl(String phone) =>
      '${AppConfig.apiBaseUrl}/api/device/ping';

  /// 안드로이드에서 수신한 SMS 내용을 서버에 저장/판정 요청한다.
  /// 서버 DTO 이름에 맞춰 발신자는 sendId, 수신자는 receiveId, 본문은 message로 보낸다.
  static Future<void> sendParsedSms({
    required String sender,
    required String receiver,
    required String body,
  }) async {

    print(('푸시보냄'));
    final response = await http
        .post(
          _u('/api/message/incoming'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'sendId': sender,
            'receiveId': receiver,
            'message': body,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('SMS sent to API');
      return;
    }

    debugPrint('SMS API error: ${response.statusCode} - ${response.body}');
    throw http.ClientException(
      'SMS API error: ${response.statusCode}',
      _u('/api/message/incoming'),
    );
  }
}
