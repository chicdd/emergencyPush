import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notifications.dart';

/// 백그라운드(앱 종료/백그라운드 상태)에서 메시지 수신 시 호출.
/// 반드시 최상위 함수 + vm:entry-point 여야 한다.
/// (이 상태에서는 시스템이 채널 설정대로 알림/소리를 직접 표시한다.)
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('백그라운드 푸시 수신: ${message.messageId}');
}

/// FCM 초기화 및 토큰/메시지 처리.
class FcmService {
  static final _messaging = FirebaseMessaging.instance;

  /// 권한 요청 후 FCM 등록 토큰을 반환(실패 시 null).
  static Future<String?> requestPermissionAndToken() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      // iOS: 포그라운드에서도 배너+소리를 표시하도록 설정.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM 토큰 획득 실패: $e');
      return null;
    }
  }

  /// 포그라운드 수신 / 알림 탭 리스너 등록.
  /// [onEmergency] 는 비상 푸시가 도착했을 때(또는 탭으로 열렸을 때) 호출된다.
  static void listen({required VoidCallback onEmergency}) {
    // 포그라운드 수신: firebase_messaging 은 이때 알림을 자동 표시하지 않으므로
    // Android 는 로컬 알림으로 직접 소리를 낸다. (iOS 는 위 presentation 옵션이 처리)
    FirebaseMessaging.onMessage.listen((message) {
      if (!_isEmergency(message)) return;
      if (Platform.isAndroid) {
        final n = message.notification;
        LocalNotifications.show(
          n?.title ?? '비상 상황',
          n?.body ?? '비상 상황이 감지되었습니다.',
        );
      }
      onEmergency();
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
