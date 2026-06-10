import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';
import 'settings_screen.dart';

/// 홈 화면: '정상' 텍스트 + 초록↔파랑 호흡(breathing) 그라데이션 애니메이션.
/// 오른쪽 위 반투명 설정(gear) 아이콘.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _healthTimer;
  bool _serverUnreachable = false;

  @override
  void initState() {
    super.initState();
    // 4초 주기로 부드럽게 들숨/날숨 반복
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // 0→1→0 사인 곡선으로 색/크기 보간 (호흡 느낌)
                final t = (math.sin(_controller.value * math.pi * 2 - math.pi / 2) + 1) / 2;
                final color = Color.lerp(AppColors.breatheBlue, AppColors.breatheGreen, t)!;
                final scale = 0.82 + 0.18 * t;
                final glow = 0.30 + 0.45 * t;

                return Center(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppColors.background,
                          AppColors.background,
                        ],
                      ),
                    ),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              color.withValues(alpha: 0.95),
                              color.withValues(alpha: 0.18),
                              AppColors.background.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: glow),
                              blurRadius: 120,
                              spreadRadius: 40,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 중앙 '정상' 텍스트
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '정상',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'SYSTEM NORMAL',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 4,
                    color: Color(0xFFB8C6D8),
                  ),
                ),
              ],
            ),
          ),
          // 서버 접속 실패 경고 배너
          if (_serverUnreachable)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  color: const Color(0x4FFF0000),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: const Text(
                    '서버 접속 실패\n비상 신호를 받지 못 합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          // 오른쪽 위 반투명 설정 아이콘
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: '설정',
                  icon: Icon(
                    Icons.settings,
                    size: 28,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
