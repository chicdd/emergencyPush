import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';
import 'settings_screen.dart';

/// 홈 화면: '정상' + 레이더 링 + 레드↔블루 호흡 애니메이션.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _breathe; // 4초 호흡
  late final AnimationController _radar;   // 3초 레이더 링
  Timer? _healthTimer;
  bool _serverUnreachable = false;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _checkServer();
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkServer());
  }

  Future<void> _checkServer() async {
    final ok = await ApiService.checkHealth();
    if (mounted && ok != !_serverUnreachable) {
      setState(() => _serverUnreachable = !ok);
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _breathe.dispose();
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 레이더 링 (배경)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _radar,
              builder: (_, __) => CustomPaint(
                painter: _RadarPainter(
                  progress: _radar.value,
                  color: AppColors.breatheBlue,
                ),
              ),
            ),
          ),
          // 호흡 오브 (중앙 글로우)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _breathe,
              builder: (_, __) {
                final t = (math.sin(_breathe.value * math.pi * 2 - math.pi / 2) + 1) / 2;
                // 파랑에서 아주 살짝 초록으로만 변화, t를 0.15로 제한
                final color = Color.lerp(AppColors.breatheBlue, const Color(0xFF00C896), t * 0.15)!;
                final scale = 0.80 + 0.06 * t;   // 크기 변화 최소화
                final glow  = 0.22 + 0.10 * t;   // 밝기 변화 최소화
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
          // 중앙 텍스트
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '정상',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 10,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: AppColors.breatheRed.withValues(alpha: 0.6),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SYSTEM NORMAL',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 5,
                    color: AppColors.techBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // 서버 접속 실패 배너
          if (_serverUnreachable)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.danger.withValues(alpha: 0.85),
                        AppColors.danger.withValues(alpha: 0.60),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: const Text(
                    '서버 접속 실패 — 비상 신호를 받지 못합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          // 설정 버튼
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: '설정',
                  icon: Icon(
                    Icons.settings_outlined,
                    size: 28,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 레이더/소나 링 페인터 — 3개의 링이 중심에서 바깥으로 퍼짐.
class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

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

    // 바깥 테두리 링 (고정, 흐린 파랑)
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, maxRadius, borderPaint);

    // 테두리 링 위 점 장식 (12개)
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
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}
