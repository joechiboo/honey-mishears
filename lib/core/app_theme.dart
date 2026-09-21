import 'package:flutter/material.dart';

/// 溫柔婉約的配色：奶油底 + 櫻花粉 + 一點薰衣草紫
class AppTheme {
  AppTheme._();

  static const Color cream = Color(0xFFFFF6F0);
  static const Color blush = Color(0xFFF7C8D0);
  static const Color rose = Color(0xFFE79AA8);
  static const Color deepRose = Color(0xFFB4687A);
  static const Color lavender = Color(0xFFD9CCEA);
  static const Color ink = Color(0xFF5B4A50);

  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: rose,
        brightness: Brightness.light,
      ).copyWith(surface: cream),
    );

    return base.copyWith(
      scaffoldBackgroundColor: cream,
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    );
  }

  /// 背景漸層（由上而下，像清晨的房間）
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF1F3), cream, Color(0xFFF3EEF8)],
  );
}
