import 'package:flutter/material.dart';

/// Renders the app logo from `assets/logo/logo.png`. Until you add that file,
/// it shows a shield + "SecureBank" placeholder, so the auth screens always
/// look complete. Drop your PNG at assets/logo/logo.png and it appears here.
class AppLogo extends StatelessWidget {
  final double height;
  final Color color; // used only by the placeholder
  final bool showWordmark; // show "SecureBank" under the placeholder mark

  const AppLogo({
    super.key,
    this.height = 64,
    this.color = Colors.white,
    this.showWordmark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(height * 0.18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.shield_outlined, color: color, size: height * 0.6),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 10),
          Text(
            'SecureBank',
            style: TextStyle(
              color: color,
              fontSize: height * 0.34,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
