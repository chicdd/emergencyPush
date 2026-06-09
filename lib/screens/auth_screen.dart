import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../services/session.dart';
import '../theme.dart';
import 'home_screen.dart';

/// 시작 화면: 휴대폰번호 + 비밀번호 + 인증 버튼.
/// 비밀번호가 01579# 이면 홈으로, 틀리면 빨간 인증 실패 텍스트.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _failed = false;
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final phone = _phoneCtrl.text.trim();
    final pw = _pwCtrl.text;

    if (pw != AppConfig.authPassword || phone.isEmpty) {
      setState(() => _failed = true);
      return;
    }

    setState(() {
      _failed = false;
      _loading = true;
    });

    // FCM 토큰 획득 후 서버에 휴대폰번호 + 토큰 등록
    final token = await FcmService.requestPermissionAndToken();
    await ApiService.register(phone, token);
    await Session.savePhone(phone);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF0B1622), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_moon_outlined,
                      size: 64, color: AppColors.accent),
                  const SizedBox(height: 18),
                  const Text(
                    'EMERGENCY PUSH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '비상상황 대응 시스템',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, letterSpacing: 1),
                  ),
                  const SizedBox(height: 44),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 1),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
                    ],
                    decoration: const InputDecoration(
                      hintText: '휴대폰번호',
                      prefixIcon: Icon(Icons.smartphone, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 3),
                    decoration: const InputDecoration(
                      hintText: '비밀번호',
                      prefixIcon: Icon(Icons.lock_outline, color: AppColors.textMuted),
                    ),
                    onSubmitted: (_) => _authenticate(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _authenticate,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Color(0xFF021016)),
                          )
                        : const Text('인증'),
                  ),
                  const SizedBox(height: 10),
                  AnimatedOpacity(
                    opacity: _failed ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Text(
                      '인증 실패',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.danger, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
