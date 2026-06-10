import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'services/fcm_service.dart';
import 'services/session.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/emergency_screen.dart';
import 'theme.dart';

/// 전역 navigator key — FCM 핸들러 등 컨텍스트 밖에서 화면 전환에 사용.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  //firebase 초기화
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    // 포그라운드에서도 배너+소리+뱃지 표시 (로그인 여부와 무관하게 항상 설정)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase 초기화 실패(설정 확인 필요): $e');
  }

  final phone = await Session.getPhone();
  final launchedFromEmergency =
      firebaseReady ? await FcmService.launchedFromEmergency() : false;

  // 이미 로그인된 경우에도 토큰을 갱신해 서버에 재등록
  if (firebaseReady && phone != null) {
    final token = await FcmService.requestPermissionAndToken();
    if (token != null) await ApiService.register(phone, token);
  }

  runApp(EmergencyPushApp(
    startLoggedIn: phone != null,
    startEmergency: launchedFromEmergency && phone != null,
  ));
}

/// 비상 화면을 전역에서 띄운다(중복 방지).
void showEmergency() {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  // 이미 비상 화면이 떠 있으면 중복 푸시하지 않음
  bool alreadyOpen = false;
  nav.popUntil((route) {
    if (route.settings.name == EmergencyScreen.routeName) alreadyOpen = true;
    return true;
  });
  if (alreadyOpen) return;

  nav.push(MaterialPageRoute(
    settings: const RouteSettings(name: EmergencyScreen.routeName),
    builder: (_) => const EmergencyScreen(),
  ));
}

class EmergencyPushApp extends StatefulWidget {
  final bool startLoggedIn;
  final bool startEmergency;

  const EmergencyPushApp({
    super.key,
    required this.startLoggedIn,
    required this.startEmergency,
  });

  @override
  State<EmergencyPushApp> createState() => _EmergencyPushAppState();
}

class _EmergencyPushAppState extends State<EmergencyPushApp> {
  @override
  void initState() {
    super.initState();
    // 비상 푸시 수신/탭 시 전역으로 비상 화면 표시
    FcmService.listen(onEmergency: showEmergency);

    if (widget.startEmergency) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showEmergency());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '비상상황 푸시',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildAppTheme(),
      home: widget.startLoggedIn ? const HomeScreen() : const AuthScreen(),
    );
  }
}
