import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/account_model.dart';
import '../../../utils/constants.dart';
import '../data/account_providers.dart';
import '../domain/account_view.dart';
import 'widgets/account_card.dart';

const _currencies = ['FCFA', 'USD', 'EUR'];

/// Premium create/edit account form with a live card preview.
class AccountFormScreen extends ConsumerStatefulWidget {
  final String userId;
  final AccountModel? existing;
  const AccountFormScreen({super.key, required this.userId, this.existing});

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _masked;
  late final TextEditingController _opening;
  late String _provider;
  late String _type;
  late String _currency;
  late String _status;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _name = TextEditingController(text: a?.accountName ?? '');
    _masked = TextEditingController(text: a?.maskedNumber ?? '');
    _opening = TextEditingController(
        text: a != null ? a.openingBalance.toStringAsFixed(0) : '0');
    _provider = a?.provider ?? kProviders.first;
    _type = a?.accountType ?? kAccountTypes.first;
    _currency = a?.currency ?? 'FCFA';
    _status = a?.status ?? 'Active';
  }

  @override
  void dispose() {
    _name.dispose();
    _masked.dispose();
    _opening.dispose();
    super.dispose();
  }

  AccountModel _preview() => AccountModel(
        id: widget.existing?.id ?? 'preview',
        userId: widget.userId,
        accountName:
            _name.text.trim().isEmpty ? 'Account name' : _name.text.trim(),
        provider: _provider,
        accountType: _type,
        maskedNumber: _masked.text.trim(),
        openingBalance: double.tryParse(_opening.text.trim()) ?? 0,
        currency: _currency,
        status: _status,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final account = AccountModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      userId: widget.userId,
      accountName: _name.text.trim(),
      provider: _provider,
      accountType: _type,
      maskedNumber: _masked.text.trim(),
      openingBalance: double.tryParse(_opening.text.trim()) ?? 0,
      currency: _currency,
      status: _status,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    try {
      final repo = ref.read(accountRepositoryProvider);
      if (_isEditing) {
        await repo.update(account);
      } else {
        await repo.create(account);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit account' : 'Add account'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AccountCard(item: AccountWithBalance(_preview(), 0)),
                  const SizedBox(height: 20),
                  const Text(
                      'We never ask for your PIN, password, or bank '
                      'login — just a friendly profile.',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  _field(
                    controller: _name,
                    label: 'Account name (e.g. My MTN MoMo)',
                    icon: Icons.badge_outlined,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  _dropdown(
                    label: 'Provider',
                    icon: Icons.business_outlined,
                    value: _provider,
                    items: kProviders,
                    onChanged: (v) => setState(() => _provider = v!),
                  ),
                  const SizedBox(height: 14),
                  _dropdown(
                    label: 'Account type',
                    icon: Icons.category_outlined,
                    value: _type,
                    items: kAccountTypes,
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _masked,
                    label: 'Masked number (e.g. ****4582)',
                    icon: Icons.tag,
                    hint: 'Optional — never enter your full number',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _field(
                          controller: _opening,
                          label: 'Opening balance',
                          icon: Icons.account_balance_wallet_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                          ],
                          validator: (v) {
                            final n = double.tryParse((v ?? '').trim());
                            if (n == null) return 'Enter a number';
                            if (n < 0) return 'Cannot be negative';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dropdown(
                          label: 'Currency',
                          icon: Icons.attach_money,
                          value: _currency,
                          items: _currencies,
                          onChanged: (v) => setState(() => _currency = v!),
                        ),
                      ),
                    ],
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                      title: const Text('Account active'),
                      subtitle: const Text(
                          'Inactive accounts are excluded from dashboard totals',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                      value: _status == 'Active',
                      onChanged: (v) =>
                          setState(() => _status = v ? 'Active' : 'Inactive'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(_isEditing ? 'Save changes' : 'Add account'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((i) => DropdownMenuItem(
              value: i, child: Text(i, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
