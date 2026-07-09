import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/validators.dart';

/// A 4-segment strength bar + label driven by [Validators.passwordStrength].
class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final score = Validators.passwordStrength(password);
    final color = switch (score) {
      <= 1 => AppTokens.danger,
      2 => AppTokens.warning,
      3 => const Color(0xFF3DA5E8),
      _ => AppTokens.success,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              final filled = i < score;
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: filled
                        ? color
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            Validators.strengthLabel(score),
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
