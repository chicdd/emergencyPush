import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'services/fcm_service.dart';
import 'screens/splash_screen.dart';
import 'screens/emergency_screen.dart';
import 'theme.dart';

/// 전역 navigator key — FCM 핸들러 등 컨텍스트 밖에서 화면 전환에 사용.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EmergencyPushApp());
}

/// 비상 화면을 전역에서 띄운다(중복 방지).
void showEmergency() {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
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
  const EmergencyPushApp({super.key});

  @override
  State<EmergencyPushApp> createState() => _EmergencyPushAppState();
}

class _EmergencyPushAppState extends State<EmergencyPushApp> {
  @override
  void initState() {
    super.initState();
    FcmService.listen(onEmergency: showEmergency);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '비상상황 푸시',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
