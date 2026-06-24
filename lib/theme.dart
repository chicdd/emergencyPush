import 'package:flutter/material.dart';

/// 비상상황 알림 — 다크 + 사이렌 레드 + 테크 블루 테마.
class AppColors {
  static const Color background  = Color(0xFF05070A); // 거의 검정
  static const Color surface     = Color(0xFF0E141B);
  static const Color surfaceAlt  = Color(0xFF131C26);

  // 홈 화면 호흡 그라데이션 (빨강 ↔ 파랑)
  static const Color breatheRed  = Color(0xFFFF1A2E); // 사이렌 레드
  static const Color breatheBlue = Color(0xFF1E6BFF); // 테크 블루

  static const Color accent      = Color(0xFFFF1A2E); // 주요 액션 색상 (빨강)
  static const Color techBlue    = Color(0xFF1E6BFF); // 보조 테크 색상 (파랑)
  static const Color textPrimary = Color(0xFFEAF2FF);
  static const Color textMuted   = Color(0xFF8A97A8);
  static const Color danger      = Color(0xFFFF1A2E);

  static const Color fieldFill   = Color(0xFF0C1118);
  static const Color fieldBorder = Color(0xFF1E2D3D);

  // 조치중(상황확인됨, 미재무장) 화면 호흡 그라데이션 (노랑 ↔ 주황)
  static const Color situationYellow = Color(0xFFFFC107);
  static const Color situationOrange = Color(0xFFFF8A00);
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      secondary: AppColors.techBlue,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamily: 'Roboto',
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.fieldFill,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.techBlue, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
  );
}
