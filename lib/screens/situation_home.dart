import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session.dart';
import '../theme.dart';
import 'home_screen.dart';

/// 조치중 화면: 비상 상황은 해제됐지만 재무장(Arm) 전이라 새 비상 감지가
/// 잠겨 있는 상태(상황확인여부 == 1). home_screen 의 레이더 링 + 호흡 애니메이션을
/// 노랑-주황 톤으로 변형해 "처리 중"임을 표현한다.
/// - 하단 '상황 복구' 버튼 → ArmStart 호출 → 정상(HomeScreen) 으로 전환.
/// - 다른 기기에서 먼저 재무장한 경우를 대비해 주기적으로 상태를 확인한다.
class SituationHomeScreen extends StatefulWidget {
  const SituationHomeScreen({super.key});

  @override
  State<SituationHomeScreen> createState() => _SituationHomeScreenState();
}

class _SituationHomeScreenState extends State<SituationHomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _breathe; // 2초 호흡 (조치중이라 정상보다 빠르게)
  late final AnimationController _radar;   // 2.2초 레이더 링
  Timer? _pollTimer;
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkArmedElsewhere());
  }

  /// 다른 기기에서 이미 "상황 복구"(재무장)를 눌렀다면 정상 화면으로 전환.
  Future<void> _checkArmedElsewhere() async {
    final status = await ApiService.getStatus();
    final acknowledged = status?['acknowledged'] == true;
    if (!acknowledged && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _breathe.dispose();
    _radar.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    setState(() => _recovering = true);
    final phone = await Session.getPhone();
    await ApiService.armStart(phone);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // 레이더 링 (배경)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _radar,
                builder: (_, __) => CustomPaint(
                  painter: _SituationRadarPainter(
                    progress: _radar.value,
                    color: AppColors.situationOrange,
                  ),
                ),
              ),
            ),
            // 호흡 오브 (중앙 글로우, 노랑 ↔ 주황)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _breathe,
                builder: (_, __) {
                  final t = (math.sin(_breathe.value * math.pi * 2 - math.pi / 2) + 1) / 2;
                  final color = Color.lerp(AppColors.situationYellow, AppColors.situationOrange, t)!;
                  final scale = 0.80 + 0.08 * t;
                  final glow = 0.25 + 0.15 * t;
                  return Center(
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              color.withValues(alpha: 0.90),
                              color.withValues(alpha: 0.15),
                              AppColors.background.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.50, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: glow),
                              blurRadius: 130,
                              spreadRadius: 45,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  // 중앙 텍스트
                  Text(
                    '조치중',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: AppColors.situationOrange.withValues(alpha: 0.6),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'In progress',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 5,
                      color: AppColors.situationYellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // 하단 '상황 복구' 버튼 (emergency_screen 의 '상황 해제'와 동일 위치/스타일)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.situationOrange,
                          minimumSize: const Size.fromHeight(60),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _recovering ? null : _recover,
                        child: _recovering
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.6, color: AppColors.situationOrange))
                            : const Text(
                                '상황 복구',
                                style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 조치중 화면용 레이더 링 — home_screen 의 레이더와 동일한 구조, 주황 톤.
class _SituationRadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SituationRadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.46;

    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final radius = maxRadius * phase;
      final opacity = (1.0 - phase) * 0.5;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, radius, paint);
    }

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, maxRadius, borderPaint);

    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    for (int d = 0; d < 12; d++) {
      final angle = d * math.pi * 2 / 12;
      final dx = center.dx + maxRadius * math.cos(angle);
      final dy = center.dy + maxRadius * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SituationRadarPainter old) => old.progress != progress;
}
