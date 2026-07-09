import 'package:flutter/material.dart';

/// Centralises navigation transitions so screens don't build routes inline.
class NavigationService {
  NavigationService._();

  /// A smooth fade page transition.
  static Route<T> fadeRoute<T>(Widget page, {int durationMs = 450}) =>
      PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration(milliseconds: durationMs),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  /// Replace the current route with [page] (used at startup / onboarding end).
  static void replaceWith(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(fadeRoute(page));
  }
}
