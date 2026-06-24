import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// 로컬 알림 표시와 비상 알림 소리 정지를 담당한다.
///
/// Android 8 이상에서는 알림 소리/중요도가 "알림 채널" 단위로 결정된다.
/// 그래서 앱 시작 시 emergency_channel을 만들고, 비상 알림은 이 채널로 표시한다.
class LocalNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const String channelId = 'emergency_channel';
  static const String channelName = '비상 알림';
  static const String channelDesc = '비상 상황 메시지 알림(소리/진동)';

  /// 비상 알림은 하나의 고정 ID로 유지한다.
  /// 새 ID를 계속 만들면 알림이 누적되고, 푸시가 반복될 때마다 소리도 다시 날 수 있다.
  static const int emergencyNotificationId = 1001;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDesc,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  /// 소리 나는 비상 알림을 표시한다.
  static Future<void> show(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _plugin.show(
      id: emergencyNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// 비상 상황 해제 시 현재 울리는 알람음과 표시된 비상 알림을 정리한다.
  static Future<void> stopEmergencyAlert() async {
    await FlutterRingtonePlayer().stop();
    await _plugin.cancel(id: emergencyNotificationId);
  }
}
