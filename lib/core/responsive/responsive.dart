import 'package:flutter/material.dart';

/// Layout breakpoints for adaptive UI.
class Breakpoints {
  Breakpoints._();
  static const double tablet = 600;
  static const double desktop = 1024;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isTablet => screenWidth >= Breakpoints.tablet;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;
}

/// Centers content and caps its width on large screens so forms don't stretch
/// edge-to-edge on tablets/desktops. Scrolls when vertical space is tight
/// (e.g. landscape), preventing RenderFlex overflow.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    );
    if (scrollable) {
      content = SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: content,
      );
    }
    return Center(child: content);
  }
}
