import 'dart:ui' show DartPluginRegistrant;

import 'package:another_telephony/telephony.dart';
import 'package:emergencypush/services/api_service.dart';
import 'package:flutter/material.dart';

import 'screens/emergency_screen.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';
import 'services/session.dart';
import 'theme.dart';

/// 전역 navigator key.
/// FCM 핸들러처럼 BuildContext 밖에서 비상 화면으로 전환할 때 사용한다.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// SMS 수신 시 서버로 전송하는 공통 처리 함수.
/// 앱이 켜져 있을 때와 백그라운드일 때 모두 이 함수를 사용한다.
Future<void> _sendIncomingSmsFromMessage(SmsMessage message) async {
  final sender = message.address ?? 'Unknown';
  final body = message.body ?? '';

  // 서버의 receiveId에는 현재 앱에 등록된 휴대폰 번호를 우선 사용한다.
  final receiver = await Session.getPhone() ?? 'MyDevicePhoneNumber';

  await ApiService.sendParsedSms(
    sender: sender,
    receiver: receiver,
    body: body,
  );
}

/// 앱이 백그라운드이거나 실행 중이 아닐 때 SMS를 받으면 호출되는 핸들러.
/// another_telephony 규칙상 top-level 함수여야 하며 entry-point로 보존해야 한다.
@pragma('vm:entry-point')
Future<void> backGroundSmsHandler(SmsMessage message) async {
  // 백그라운드 isolate에서도 플러그인과 Flutter binding을 사용할 수 있게 초기화한다.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    await _sendIncomingSmsFromMessage(message);
  } catch (e) {
    debugPrint('Background SMS service error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EmergencyPushApp());
}

/// 비상 화면을 전역에서 띄운다.
/// 이미 비상 화면이 열려 있으면 중복으로 push하지 않는다.
void showEmergency() {
  final nav = navigatorKey.currentState;
  if (nav == null) return;

  var alreadyOpen = false;
  nav.popUntil((route) {
    if (route.settings.name == EmergencyScreen.routeName) alreadyOpen = true;
    return true;
  });
  if (alreadyOpen) return;

  nav.push(
    MaterialPageRoute(
      settings: const RouteSettings(name: EmergencyScreen.routeName),
      builder: (_) => const EmergencyScreen(),
    ),
  );
}

class EmergencyPushApp extends StatefulWidget {
  const EmergencyPushApp({super.key});

  @override
  State<EmergencyPushApp> createState() => _EmergencyPushAppState();
}

class _EmergencyPushAppState extends State<EmergencyPushApp> {
  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    initSmsListener();
    FcmService.listen(onEmergency: showEmergency);
  }

  /// Android SMS/전화 권한을 요청한 뒤 수신 리스너를 등록한다.
  Future<void> initSmsListener() async {
    final permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != true) return;

    telephony.listenIncomingSms(
      listenInBackground: true,
      // 앱이 켜져 있을 때 수신한 SMS 처리.
      onNewMessage: (SmsMessage message) async {
        try {
          await _sendIncomingSmsFromMessage(message);
        } catch (e) {
          debugPrint('Foreground SMS service error: $e');
        }
      },
      // 앱이 백그라운드이거나 실행 중이 아닐 때 수신한 SMS 처리.
      onBackgroundMessage: backGroundSmsHandler,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '비상상황 메시지',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
