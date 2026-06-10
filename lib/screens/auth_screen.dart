import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../services/session.dart';
import '../theme.dart';
import 'home_screen.dart';

/// 시작 화면: 휴대폰번호 + 비밀번호 + 인증 버튼.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _pwCtrl    = TextEditingController();
  bool _failed  = false;
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final phone = _phoneCtrl.text.trim();
    final pw    = _pwCtrl.text;

    if (pw != AppConfig.authPassword || phone.isEmpty) {
      setState(() => _failed = true);
      return;
    }

    setState(() { _failed = false; _loading = true; });

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
            radius: 1.4,
            colors: [Color(0xFF1A000A), AppColors.background],
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
                  // 사이렌 아이콘 + 글로우
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.1),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.25),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 48,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '비상 상황 알림',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'EMERGENCY ALERT SYSTEM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.techBlue,
                      letterSpacing: 2,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
                      prefixIcon: Icon(Icons.smartphone_outlined, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 14),
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
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
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
                      style: TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600),
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
