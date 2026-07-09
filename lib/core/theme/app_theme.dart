import 'package:flutter/material.dart';

/// Design tokens for SecureBank's premium fintech look.
class AppTokens {
  AppTokens._();

  // Brand palette derived from the SecureBank logo (blue → purple).
  static const brand = Color(0xFF3E74FF); // logo shield blue
  static const brandDeep = Color(0xFF2348C8);
  static const accent = Color(0xFF9B37E0); // logo purple / magenta
  static const success = Color(0xFF1FA96A);
  static const warning = Color(0xFFE8A33D);
  static const danger = Color(0xFFEF4E4E);

  // Dark surfaces, tinted toward the logo's deep indigo/purple.
  static const darkBg = Color(0xFF0A0B18);
  static const darkBgTop = Color(0xFF181735);
  static const darkSurface = Color(0xFF1B1B38);

  static const radiusSm = 10.0;
  static const radius = 14.0;
  static const radiusLg = 20.0;
  static const radiusPill = 40.0;

  static const gapXs = 8.0;
  static const gap = 16.0;
  static const gapLg = 24.0;
}

/// Central Material 3 themes (light + dark). Screens should read colours from
/// `Theme.of(context).colorScheme` rather than hardcoding values.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.brand,
      brightness: brightness,
    ).copyWith(
      error: AppTokens.danger,
      surface: isDark ? AppTokens.darkSurface : Colors.white,
    );

    final radius = BorderRadius.circular(AppTokens.radius);
    final fieldFill =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F5F9);

    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppTokens.darkBg : const Color(0xFFF5F7FB),
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme:
            IconThemeData(color: isDark ? Colors.white : scheme.onSurface),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        labelStyle:
            TextStyle(color: isDark ? Colors.white60 : const Color(0xFF7A8699)),
        floatingLabelStyle:
            TextStyle(color: isDark ? Colors.white : AppTokens.brand),
        prefixIconColor: isDark ? Colors.white54 : const Color(0xFF7A8699),
        border: border(Colors.transparent, 0),
        enabledBorder:
            border(isDark ? Colors.white24 : const Color(0xFFE2E6EF), 1),
        focusedBorder: border(AppTokens.brand, 1.6),
        errorBorder: border(AppTokens.danger, 1.2),
        focusedErrorBorder: border(AppTokens.danger, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    );
  }
}
