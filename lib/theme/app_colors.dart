import 'package:flutter/material.dart';

class AppColors {
  // Deep Backgrounds
  static const Color background = Color(0xFF090A10);
  static const Color surface = Color(0xFF131520);
  static const Color surfaceLight = Color(0xFF1C1E2E);
  static const Color surfaceGlass = Color(0xCC181A28);
  static const Color glassBorder = Color(0x338A94B8);
  static const Color glassBorderActive = Color(0x80FF2D78);

  // Brand / Accents
  static const Color primary = Color(0xFFFF2D78);       // Vibrant Rose/Pink
  static const Color primaryLight = Color(0xFFFF66A1);
  static const Color primaryDark = Color(0xFFC00E52);
  static const Color secondary = Color(0xFF8A3FFC);     // Electric Violet
  static const Color secondaryLight = Color(0xFFA56EFF);
  static const Color tertiary = Color(0xFF00D2FF);      // Cyan Glow
  static const Color accent = Color(0xFF00D2FF);        // Cyan Accent

  // Diamonds & Currency
  static const Color diamond = Color(0xFF00E5FF);
  static const Color diamondLight = Color(0xFFB3F5FF);
  static const Color diamondDark = Color(0xFF0099B8);
  static const Color gold = Color(0xFFFFB800);
  static const Color goldLight = Color(0xFFFFE072);
  static const Color goldDark = Color(0xFFB87800);

  // Status & Sentiment
  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF4D4F);
  static const Color warning = Color(0xFFFFA940);
  static const Color info = Color(0xFF40A9FF);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B6C8);
  static const Color textTertiary = Color(0xFF757C95);
  static const Color textDisabled = Color(0xFF4A4E63);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF2D78), Color(0xFF8A3FFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient romanticGradient = LinearGradient(
    colors: [Color(0xFFFF3366), Color(0xFFFF6584)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFE072), Color(0xFFFFB800), Color(0xFFD48800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient diamondGradient = LinearGradient(
    colors: [Color(0xFFB3F5FF), Color(0xFF00E5FF), Color(0xFF0099B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x33282C40), Color(0x1A1E2235)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0x26FF2D78), Color(0x1A8A3FFC), Color(0x00000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkFadeGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xBF090A10), Color(0xFF090A10)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
