import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Theme-aware text field used across the auth screens. Handles its own
/// show/hide toggle when [obscure] is true, and supports realtime validation
/// via [onChanged] + [autovalidateMode].
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.suffix,
    this.enabled = true,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final Widget? suffix = widget.obscure
        ? IconButton(
            icon: Icon(
                _obscured ? Icons.visibility_off : Icons.visibility, size: 20),
            onPressed: () => setState(() => _obscured = !_obscured),
          )
        : widget.suffix;

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}
