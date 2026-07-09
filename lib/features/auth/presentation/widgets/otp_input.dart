import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium 6-box OTP field: auto-advances as you type and pasting a full code
/// fills every box. Calls [onCompleted] once all [length] digits are entered.
class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const OtpInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _distribute(String pasted) {
    final digits = pasted.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < widget.length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    final next = digits.length.clamp(0, widget.length - 1);
    _nodes[next].requestFocus();
    _emit();
  }

  void _onChanged(int i, String value) {
    if (value.length > 1) {
      _distribute(value);
      return;
    }
    if (value.isNotEmpty && i < widget.length - 1) {
      _nodes[i + 1].requestFocus();
    } else if (value.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
    }
    _emit();
  }

  void _emit() {
    final code = _code;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      FocusScope.of(context).unfocus();
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        return SizedBox(
          width: 46,
          child: TextField(
            controller: _controllers[i],
            focusNode: _nodes[i],
            enabled: widget.enabled,
            autofocus: i == 0,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: i == 0 ? widget.length : 1,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              filled: true,
              fillColor: scheme.surface.withValues(alpha: 0.6),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.primary, width: 1.8),
              ),
            ),
            onChanged: (v) => _onChanged(i, v),
          ),
        );
      }),
    );
  }
}
