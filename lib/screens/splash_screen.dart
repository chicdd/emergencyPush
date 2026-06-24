import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../main.dart' show showEmergency;
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../services/session.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'situation_home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _initialize();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    bool firebaseReady = false;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase 초기화 실패: $e');
    }

    final phone = await Session.getPhone();
    final launchedFromEmergency =
        firebaseReady ? await FcmService.launchedFromEmergency() : false;

    if (firebaseReady && phone != null) {
      final token = await FcmService.requestPermissionAndToken();
      if (token != null) await ApiService.register(phone, token);
    }

    Widget next;
    if (phone == null) {
      next = const AuthScreen();
    } else {
      final status = await ApiService.getStatus();
      next = status?['acknowledged'] == true
          ? const SituationHomeScreen()
          : const HomeScreen();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (launchedFromEmergency && phone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showEmergency());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 사이렌 아이콘 + 글로우
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 52,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              '비상 상황 알림',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'EMERGENCY ALERT SYSTEM',
              style: TextStyle(
                color: AppColors.techBlue,
                fontSize: 10,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              '사용자 정보 불러오는 중',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _AnimatedDots(controller: _dotController),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDots extends AnimatedWidget {
  const _AnimatedDots({required AnimationController controller})
      : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as AnimationController).value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = (t - i * 0.3).clamp(0.0, 1.0);
        final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.2, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Opacity(
            opacity: opacity,
            child: const CircleAvatar(
              radius: 4.5,
              backgroundColor: AppColors.accent,
            ),
          ),
        );
      }),
    );
  }
}
