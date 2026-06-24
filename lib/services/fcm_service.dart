import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// 앱이 종료/백그라운드 상태일 때 FCM을 받으면 호출된다.
/// 반드시 top-level 함수이고 vm entry-point여야 한다.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // 백그라운드에서는 시스템 알림이 표시되고, 사용자가 누르면 onMessageOpenedApp으로 들어온다.
  debugPrint('Background FCM received: ${message.messageId}');
}

/// FCM 초기화, 토큰 요청, 비상 푸시 처리.
class FcmService {
  static final _messaging = FirebaseMessaging.instance;

  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onOpenedSub;

  /// 서버는 비상 상태 동안 푸시를 반복 전송한다.
  /// 앱 안에서는 한 번만 화면/알람을 발동시키기 위해 현재 처리 중인 비상 여부를 기억한다.
  static bool _emergencyHandledInApp = false;

  /// 권한 요청 후 FCM 등록 토큰을 반환한다. 실패하면 null.
  static Future<String?> requestPermissionAndToken() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] permission: ${settings.authorizationStatus}');
      debugPrint(
        '[FCM] alert=${settings.alert} sound=${settings.sound} badge=${settings.badge}',
      );

      final token = await _messaging.getToken();
      debugPrint('[FCM] token: $token');
      return token;
    } catch (e, st) {
      debugPrint('FCM token error: $e\n$st');
      return null;
    }
  }

  /// foreground 수신 / 알림 탭 리스너 등록.
  /// 같은 앱 프로세스에서 중복 등록되지 않도록 기존 구독을 재사용한다.
  static void listen({required VoidCallback onEmergency}) {
    if (_onMessageSub != null || _onOpenedSub != null) {
      debugPrint('[FCM] listeners already registered');
      return;
    }

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] onMessage received');
      debugPrint(
        '[FCM] notification: ${message.notification?.title} / ${message.notification?.body}',
      );
      debugPrint('[FCM] data: ${message.data}');

      if (_isEmergency(message) && _markEmergencyHandled()) {
        //비상이 울린 후 앱에 접속했을 때 소리남
        // FlutterRingtonePlayer().playAlarm(volume: 1.0);
        onEmergency();
      }
    });

    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (_isEmergency(message) && _markEmergencyHandled()) {
        onEmergency();
      }
    });
  }

  /// 앱이 종료된 상태에서 비상 알림을 눌러 시작했는지 확인한다.
  static Future<bool> launchedFromEmergency() async {
    final initial = await _messaging.getInitialMessage();
    if (initial == null || !_isEmergency(initial)) return false;

    _markEmergencyHandled();
    return true;
  }

  /// 상황 해제 후 다음 비상 푸시를 다시 처리할 수 있게 상태를 초기화한다.
  static void resetEmergencyHandling() {
    _emergencyHandledInApp = false;
  }

  /// 비상 푸시 반복 수신 중 최초 1회만 true를 반환한다.
  static bool _markEmergencyHandled() {
    if (_emergencyHandledInApp) {
      debugPrint('[FCM] repeated emergency push ignored');
      return false;
    }

    _emergencyHandledInApp = true;
    return true;
  }

  /// data.type이 emergency인 메시지만 비상 푸시로 처리한다.
  static bool _isEmergency(RemoteMessage m) => m.data['type'] == 'emergency';
}
