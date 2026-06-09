import 'package:flutter/material.dart';

/// 어둡고 미래지향적인 검은색 계열 테마.
class AppColors {
  static const Color background = Color(0xFF05070A); // 거의 검정
  static const Color surface = Color(0xFF0E141B);
  static const Color surfaceAlt = Color(0xFF131C26);

  // 홈 화면 호흡 그라데이션(초록 ↔ 파랑)
  static const Color breatheGreen = Color(0xFF00E6A8);
  static const Color breatheBlue = Color(0xFF1E6BFF);

  static const Color accent = Color(0xFF35E0F0);
  static const Color textPrimary = Color(0xFFEAF2FF);
  static const Color textMuted = Color(0xFF8A97A8);
  static const Color danger = Color(0xFFFF2D55);

  static const Color fieldFill = Color(0xFF121A22);
  static const Color fieldBorder = Color(0xFF243240);
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      secondary: AppColors.breatheGreen,
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
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: const Color(0xFF021016),
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
