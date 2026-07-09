import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Reusable typography scale for the premium header (and any screen that
/// wants consistent SecureBank type). Sits alongside [AppTokens]/[AppColors]
/// rather than replacing them — those already own the app's colors and
/// radii; this file adds the text-style half of the design language.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle headerTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.1,
  );

  static const TextStyle headerTitleCompact = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.1,
  );

  static const TextStyle headerSubtitle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
}

/// Spacing scale — mirrors [AppTokens]'s gap values and fills in the finer
/// increments dense premium UI needs (badges, chip padding, icon insets).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner-radius scale — aliases [AppTokens] so there's one name to reach
/// for ("AppRadius.md") without duplicating the underlying values.
class AppRadius {
  AppRadius._();

  static const double sm = AppTokens.radiusSm;
  static const double md = AppTokens.radius;
  static const double lg = AppTokens.radiusLg;
  static const double pill = AppTokens.radiusPill;
}
