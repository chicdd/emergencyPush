import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// 백그라운드(앱 종료/백그라운드 상태)에서 메시지 수신 시 호출.
/// 반드시 최상위 함수 + vm:entry-point 여야 한다.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // 시스템 알림 트레이로 표시되며, 사용자가 탭하면 onMessageOpenedApp 으로 진입한다.
  debugPrint('백그라운드 푸시 수신: ${message.messageId}');
}

/// FCM 초기화 및 토큰/메시지 처리.
class FcmService {
  static final _messaging = FirebaseMessaging.instance;

  /// 권한 요청 후 FCM 등록 토큰을 반환(실패 시 null).
  static Future<String?> requestPermissionAndToken() async {
    try {
      final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      debugPrint('FCM 알림 권한: ${settings.authorizationStatus}');

      // 포그라운드에서도 시스템 알림(배너+소리+뱃지) 표시
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _messaging.getToken();
      debugPrint('FCM 토큰: $token');
      return token;
    } catch (e, st) {
      debugPrint('FCM 토큰 획득 실패: $e\n$st');
      return null;
    }
  }

  /// 포그라운드 수신 / 알림 탭 리스너 등록.
  /// [onEmergency] 는 비상 푸시가 도착했을 때(또는 탭으로 열렸을 때) 호출된다.
  static void listen({required VoidCallback onEmergency}) {
    // 포그라운드 수신
    FirebaseMessaging.onMessage.listen((message) {
      if (_isEmergency(message)) onEmergency();
    });

    // 백그라운드에서 알림 탭으로 앱이 열림
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (_isEmergency(message)) onEmergency();
    });
  }

  /// 앱이 완전히 종료된 상태에서 알림 탭으로 시작되었는지 확인.
  static Future<bool> launchedFromEmergency() async {
    final initial = await _messaging.getInitialMessage();
    return initial != null && _isEmergency(initial);
  }

  static bool _isEmergency(RemoteMessage m) =>
      m.data['type'] == 'emergency' || m.notification != null;
}
