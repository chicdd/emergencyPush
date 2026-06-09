import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session.dart';
import '../theme.dart';

/// 비상 상황 화면.
/// - 가운데 빨간 사이렌 아이콘이 회전.
/// - 배경이 1초 동안 밝아지고 1초 동안 어두워지는 펄스.
/// - 하단 '상황 해제' 버튼 → 서버에 해제 요청 → 푸시 즉시 중지.
class EmergencyScreen extends StatefulWidget {
  static const routeName = 'emergency';
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    // 1초 밝아짐 + 1초 어두워짐 = 2초 주기
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    final phone = await Session.getPhone();
    await ApiService.resolveEmergency(phone);
    if (!mounted) return;
    Navigator.of(context).pop(); // 홈으로 복귀
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒤로가기로 임의 종료 방지 — 반드시 상황 해제 버튼 사용
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_pulse.value);
            final bg = Color.lerp(const Color(0xFF1A0000), const Color(0xFF7A0010), t)!;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [bg, Colors.black],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(),
                const Text(
                  '비상 상황',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 10,
                  ),
                ),
                const SizedBox(height: 48),
                // 회전하는 사이렌 아이콘
                AnimatedBuilder(
                  animation: _spin,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) {
                            final glow = 0.4 + 0.6 * _pulse.value;
                            return Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.danger.withValues(alpha: glow),
                                    blurRadius: 90,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Transform.rotate(
                          angle: _spin.value * 2 * math.pi,
                          child: const Icon(
                            Icons.emergency_share,
                            size: 130,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
                const Text(
                  '캡스 보라매 신호 미상승 감지',
                  style: TextStyle(color: Color(0xFFFFC9D2), fontSize: 14, letterSpacing: 2),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.danger,
                        minimumSize: const Size.fromHeight(60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _resolving ? null : _resolve,
                      child: _resolving
                          ? const SizedBox(
                              height: 24, width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.danger))
                          : const Text('상황 해제',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
