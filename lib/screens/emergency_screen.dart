import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../services/local_notifications.dart';
import '../services/session.dart';
import '../theme.dart';
import 'situation_home.dart';

/// 비상 상황 화면.
/// - 레이더 링이 빠르게 퍼져나가며 사이렌 아이콘 회전.
/// - 배경이 붉게 펄스.
/// - 하단 '상황 해제' 버튼.
class EmergencyScreen extends StatefulWidget {
  static const routeName = 'emergency';
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;
  late final AnimationController _radar;
  Timer? _pollTimer;
  bool _resolving = false;
  String? _emergencyMessage;
  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkResolved(),
    );
  }

  Future<void> _checkResolved() async {
    // ApiService의 getStatus()를 직접 호출해서 맵 데이터를 가져옴
    final statusMap = await ApiService.getStatus();

    if (statusMap == null) return; // 통신 실패 시 예외 처리

    final bool active = statusMap['active'] == true;

    if (!active && mounted) {
      // 해제 상태면 이동
      await LocalNotifications.stopEmergencyAlert(); //비상 울리지 않게함
      FcmService.resetEmergencyHandling();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SituationHomeScreen()),
      );
    } else if (active && mounted) {
      // 유지 상태면 맵에서 바로 메시지 꺼내기 (서버 요청 중복 방지)
      setState(() {
        _emergencyMessage = statusMap['메시지내용'] as String?;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _spin.dispose();
    _pulse.dispose();
    _radar.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    final phone = await Session.getPhone();
    await ApiService.resolveEmergency(phone);
    await LocalNotifications.stopEmergencyAlert();
    FcmService.resetEmergencyHandling();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SituationHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(_pulse.value);
            final bg = Color.lerp(
              const Color(0xFF150008),
              const Color(0xFF6B0015),
              t,
            )!;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.2,
                  colors: [bg, Colors.black],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Stack(
              children: [
                // 레이더 링 (빠른 속도)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _radar,
                    builder: (context, child) => CustomPaint(
                      painter: _EmergencyRadarPainter(progress: _radar.value),
                    ),
                  ),
                ),
                Column(
                  children: [
                    const Spacer(),
                    // "비상 상황" 타이틀
                    const Text(
                      '비상 상황',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        shadows: [
                          Shadow(color: AppColors.danger, blurRadius: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'EMERGENCY ALERT',
                      style: TextStyle(
                        color: AppColors.techBlue,
                        fontSize: 11,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 52),
                    // 회전 사이렌 아이콘
                    AnimatedBuilder(
                      animation: Listenable.merge([_spin, _pulse]),
                      builder: (context, child) {
                        final glow = 0.45 + 0.55 * _pulse.value;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // 글로우 원
                            Container(
                              width: 210,
                              height: 210,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.danger.withValues(
                                      alpha: glow,
                                    ),
                                    blurRadius: 100,
                                    spreadRadius: 30,
                                  ),
                                ],
                              ),
                            ),
                            // 외곽 링
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1.2,
                                ),
                              ),
                            ),
                            // 회전 아이콘
                            Transform.rotate(
                              angle: _spin.value * 2 * math.pi,
                              child: const Icon(
                                Icons.emergency_share_rounded,
                                size: 120,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 44),
                    Text(
                      _emergencyMessage ?? '메세지 로드 실패',
                      style: TextStyle(
                        color: Color(0xFFFFC9D2),
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _resolving ? null : _resolve,
                          child: _resolving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: AppColors.danger,
                                  ),
                                )
                              : const Text(
                                  '상황 해제',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 비상 화면용 레이더 링 — 빠르고 강렬한 빨간색.
class _EmergencyRadarPainter extends CustomPainter {
  final double progress;
  _EmergencyRadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.52;

    for (int i = 0; i < 4; i++) {
      final phase = (progress + i / 4) % 1.0;
      final radius = maxRadius * phase;
      final opacity = (1.0 - phase) * 0.65;

      final paint = Paint()
        ..color = AppColors.danger.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_EmergencyRadarPainter old) => old.progress != progress;
}
