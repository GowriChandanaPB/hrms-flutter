import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // BRAND COLORS
  // ============================================================

  static const Color primary = Color(0xFF6044E8);
  static const Color primaryDark = Color(0xFF4930C8);
  static const Color primaryLight = Color(0xFF8C78FF);
  static const Color primarySoft = Color(0xFFEAE5FF);

  static const Color secondary = Color(0xFF8D72FF);
  static const Color accent = Color(0xFFB7A7FF);

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static const Color lightBackground = Color(0xFFF6F5FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFF0EEFF);
  static const Color lightBorder = Color(0xFFE7E3F5);

  static const Color lightTextPrimary = Color(0xFF191638);
  static const Color lightTextSecondary = Color(0xFF77738F);
  static const Color lightTextMuted = Color(0xFFA5A1B8);

  // ============================================================
  // DARK THEME
  // ============================================================

  static const Color darkBackground = Color(0xFF0C1024);
  static const Color darkSurface = Color(0xFF171D38);
  static const Color darkSurfaceSecondary = Color(0xFF22294A);
  static const Color darkBorder = Color(0xFF30385C);

  static const Color darkTextPrimary = Color(0xFFF5F3FF);
  static const Color darkTextSecondary = Color(0xFFB5B8D1);
  static const Color darkTextMuted = Color(0xFF777E9F);

  // ============================================================
  // STATUS COLORS
  // ============================================================

  static const Color success = Color(0xFF16A36A);
  static const Color successLight = Color(0xFFE0F7EC);
  static const Color successDark = Color(0xFF48D6A0);

  static const Color warning = Color(0xFFF0A52B);
  static const Color warningLight = Color(0xFFFFF3D9);

  static const Color error = Color(0xFFE84D62);
  static const Color errorLight = Color(0xFFFFE7EA);

  static const Color info = Color(0xFF4389F5);
  static const Color infoLight = Color(0xFFE7F0FF);

  // ============================================================
  // GRADIENTS
  // ============================================================

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8065F7), Color(0xFF5A3BD6)],
  );

  static const LinearGradient lightCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8E2FF), Color(0xFFD5CCFF)],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF343C68), Color(0xFF202747)],
  );

  static const LinearGradient darkPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B72FF), Color(0xFF5639D7)],
  );

  // ============================================================
  // SHADOWS
  // ============================================================

  static const Color lightShadow = Color(0x14604AE8);
  static const Color darkShadow = Color(0x66000000);
}
