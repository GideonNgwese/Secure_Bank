import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

/// Date-of-birth picker styled to match the surrounding text fields, fully
/// participating in [Form] validation via [FormField].
class ProfileDateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? Function(DateTime?)? validator;

  const ProfileDateField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      initialValue: value,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (state) {
        return InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime(now.year - 18, now.month, now.day),
              firstDate: DateTime(now.year - 100),
              lastDate: now,
              helpText: 'Select date of birth',
            );
            if (picked != null) {
              onChanged(picked);
              state.didChange(picked);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, size: 20),
              errorText: state.errorText,
            ),
            child: Text(
              value == null ? 'Select date' : DateFormat.yMMMd().format(value!),
              style: TextStyle(
                color: value == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}
