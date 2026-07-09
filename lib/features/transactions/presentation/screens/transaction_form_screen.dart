import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../models/account_model.dart';
import '../../../../models/transaction_model.dart';
import '../../../accounts/data/account_providers.dart';
import '../../../email/data/email_providers.dart';
import '../../data/transaction_providers.dart';
import '../../domain/transaction_fields.dart';
import '../../domain/transaction_validators.dart';
import '../controllers/transaction_form_controller.dart';
import '../widgets/account_balance_preview.dart';
import '../widgets/category_picker.dart';
import '../widgets/receipt_picker.dart';
import '../../../fraud_detection/presentation/screens/fraud_review_screen.dart';

/// Premium create/edit transaction form. Transfers are created here but not
/// edited (they're two linked legs — see [TransactionRepository]), so when
/// editing, the type choices exclude Transfer.
class TransactionFormScreen extends ConsumerStatefulWidget {
  final String userId;
  final TransactionModel? existing;
  final String? initialType;

  const TransactionFormScreen({
    super.key,
    required this.userId,
    this.existing,
    this.initialType,
  });

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _merchant;
  late final TextEditingController _location;
  late final TextEditingController _description;

  late String _type;
  late String _category;
  String? _accountId;
  String? _toAccountId;
  late String _currency;
  late String _paymentMethod;
  late String _status;
  late DateTime _date;
  late String _receiptUrl;
  bool _adjustmentIncrease = true;
  bool _simulateNewDevice = false;

  bool get _isEditing => widget.existing != null;
  List<String> get _typeChoices => _isEditing
      ? const ['Income', 'Expense', 'Refund', 'Adjustment']
      : TransactionFields.types;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
        text: e != null ? e.amount.abs().toStringAsFixed(0) : '');
    _title = TextEditingController(text: e?.title ?? '');
    _merchant = TextEditingController(text: e?.merchant ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _description = TextEditingController(text: e?.description ?? '');

    _type = e?.type ?? widget.initialType ?? 'Expense';
    _category = e?.category ?? TransactionFields.categories.first;
    _accountId = e?.accountId;
    _currency = e?.currency.isNotEmpty == true ? e!.currency : 'FCFA';
    _paymentMethod = e?.paymentMethod.isNotEmpty == true
        ? e!.paymentMethod
        : TransactionFields.paymentMethods.first;
    _status = e?.status ?? 'Completed';
    _date = e?.transactionDate ?? DateTime.now();
    _receiptUrl = e?.receiptUrl ?? '';
    _adjustmentIncrease = (e?.amount ?? 0) >= 0;
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _merchant.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  double get _enteredAmount => double.tryParse(_amount.text.trim()) ?? 0;

  /// Signed contribution the in-progress transaction would make, used for
  /// the live balance preview and the final write for Adjustment.
  double _signedAmountFor({required bool asToLeg}) {
    final amt = _enteredAmount.abs();
    if (amt == 0) return 0;
    return switch (_type) {
      'Income' || 'Refund' => amt,
      'Expense' => -amt,
      'Adjustment' => _adjustmentIncrease ? amt : -amt,
      'Transfer' => asToLeg ? amt : -amt,
      _ => 0,
    };
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Transaction date',
    );
    if (picked != null) {
      setState(() => _date = DateTime(
          picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _pickCategory() async {
    final txs =
        ref.read(transactionsRawProvider(widget.userId)).valueOrNull ?? [];
    final options = CategoryOptions.merge(txs, mustInclude: _category);
    final picked = await showCategoryPicker(context,
        options: options, selected: _category);
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      _snack('Select an account');
      return;
    }
    if (_type == 'Transfer' &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      _snack('Select a different destination account');
      return;
    }
    FocusScope.of(context).unfocus();

    final controller = ref.read(transactionFormControllerProvider.notifier);
    final amount = _enteredAmount.abs();

    if (_type == 'Transfer') {
      final ok = await controller.createTransfer(
        userId: widget.userId,
        fromAccountId: _accountId!,
        toAccountId: _toAccountId!,
        amount: amount,
        description: _description.text.trim(),
        transactionDate: _date,
        currency: _currency,
      );
      if (ok && mounted) Navigator.of(context).pop();
      return;
    }

    final signedForAdjustment = _signedAmountFor(asToLeg: false);
    final saveAmount = _type == 'Adjustment' ? signedForAdjustment : amount;

    final result = _isEditing
        ? await controller.updateTransaction(
            original: widget.existing!,
            accountId: _accountId!,
            type: _type,
            category: _category,
            amount: saveAmount,
            title: _title.text.trim(),
            description: _description.text.trim(),
            currency: _currency,
            paymentMethod: _paymentMethod,
            merchant: _merchant.text.trim(),
            location: _location.text.trim(),
            receiptUrl: _receiptUrl,
            status: _status,
            transactionDate: _date,
            simulateNewDevice: _simulateNewDevice,
          )
        : await controller.create(
            userId: widget.userId,
            accountId: _accountId!,
            type: _type,
            category: _category,
            amount: saveAmount,
            title: _title.text.trim(),
            description: _description.text.trim(),
            currency: _currency,
            paymentMethod: _paymentMethod,
            merchant: _merchant.text.trim(),
            location: _location.text.trim(),
            receiptUrl: _receiptUrl,
            status: _status,
            transactionDate: _date,
            simulateNewDevice: _simulateNewDevice,
          );

    if (result != null && mounted) {
      // Medium+ risk transactions are held for review instead of completing
      // — hand off straight to the Fraud Review screen instead of popping
      // back to the list, so the flag can't go unnoticed.
      if (result.isPendingReview) {
        _sendFraudDetectedEmail(result);
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => FraudReviewScreen(
                userId: widget.userId, transactionId: result.id)));
      } else {
        if (!_isEditing) _sendReceiptEmail(result);
        Navigator.of(context).pop();
      }
    }
  }

  void _sendFraudDetectedEmail(TransactionModel tx) {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    ref.read(emailRepositoryProvider).fraudDetected(
          userId: widget.userId,
          email: user!.email!,
          name: user.displayName ?? '',
          riskLevel: tx.riskLevel,
          riskScore: tx.riskScore,
          reason: '${tx.riskLevel} risk ${tx.type.toLowerCase()} of '
              '${tx.amount.abs().toStringAsFixed(0)} FCFA',
          amount: tx.amount.abs(),
          referenceNumber: tx.id,
        );
  }

  /// New (not edited), non-flagged transactions get a receipt email — an
  /// edit or a Pending Review transaction doesn't (the latter gets a fraud
  /// alert email instead, and a resolution email once approved/declined).
  void _sendReceiptEmail(TransactionModel tx) {
    final receiptType = switch (tx.type) {
      'Income' || 'Refund' => 'cash_in',
      'Expense' => 'cash_out',
      'Transfer' => 'transfer',
      _ => null, // Adjustment — an internal correction, not a receipt event
    };
    if (receiptType == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    ref.read(emailRepositoryProvider).transactionReceipt(
          userId: widget.userId,
          email: user!.email!,
          name: user.displayName ?? '',
          type: receiptType,
          amount: tx.amount.abs(),
          category: tx.category,
          merchant: tx.merchant,
          referenceNumber: tx.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(transactionFormControllerProvider, (_, next) {
      if (next is AsyncError) {
        _snack((next.error as AppException).message);
      }
    });
    final saving = ref.watch(transactionFormControllerProvider).isLoading;
    final accounts =
        ref.watch(accountsRawProvider(widget.userId)).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit transaction' : 'Add transaction')),
      body: accounts.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Create an account first before adding transactions.',
                    textAlign: TextAlign.center),
              ),
            )
          : Builder(builder: (context) {
              _accountId ??= accounts.first.id;
              return ResponsiveCenter(
                maxWidth: 560,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Form(
                  key: _formKey,
                  onChanged: () => setState(() {}),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(child: _typeSelector()),
                      const SizedBox(height: 18),
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 500),
                        child: _Section(title: 'Details', children: [
                          if (_type == 'Transfer') ...[
                            _accountDropdown(
                                accounts,
                                'From account',
                                _accountId,
                                (v) => setState(() => _accountId = v)),
                            const SizedBox(height: 14),
                            _accountDropdown(
                                accounts
                                    .where((a) => a.id != _accountId)
                                    .toList(),
                                'To account',
                                _toAccountId,
                                (v) => setState(() => _toAccountId = v)),
                          ] else ...[
                            _accountDropdown(accounts, 'Account', _accountId,
                                (v) => setState(() => _accountId = v)),
                            const SizedBox(height: 14),
                            _categoryField(),
                          ],
                          if (_type == 'Adjustment') ...[
                            const SizedBox(height: 14),
                            _adjustmentDirection(),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _amount,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]')),
                                  ],
                                  decoration: const InputDecoration(
                                      labelText: 'Amount',
                                      prefixIcon: Icon(Icons.payments_outlined,
                                          size: 20)),
                                  validator: (v) =>
                                      TransactionValidators.amount(v,
                                          allowNegative: false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _currency,
                                  decoration: const InputDecoration(
                                      labelText: 'Currency'),
                                  items: TransactionFields.currencies
                                      .map((c) => DropdownMenuItem(
                                          value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _currency = v!),
                                ),
                              ),
                            ],
                          ),
                          if (_accountId != null) ...[
                            const SizedBox(height: 14),
                            AccountBalancePreview(
                              userId: widget.userId,
                              accountId: _accountId!,
                              delta: _isEditing &&
                                      widget.existing!.accountId == _accountId
                                  ? _signedAmountFor(asToLeg: false) -
                                      widget.existing!.signedAmount
                                  : _signedAmountFor(asToLeg: false),
                            ),
                          ],
                          if (_type == 'Transfer' && _toAccountId != null) ...[
                            const SizedBox(height: 10),
                            AccountBalancePreview(
                              userId: widget.userId,
                              accountId: _toAccountId!,
                              delta: _signedAmountFor(asToLeg: true),
                            ),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 550),
                        child: _Section(title: 'More info', children: [
                          TextFormField(
                            controller: _title,
                            decoration: const InputDecoration(
                                labelText: 'Title (optional)',
                                prefixIcon: Icon(Icons.short_text, size: 20)),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _merchant,
                            decoration: const InputDecoration(
                                labelText: 'Merchant (optional)',
                                prefixIcon:
                                    Icon(Icons.storefront_outlined, size: 20)),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _location,
                            decoration: const InputDecoration(
                                labelText: 'Location (optional)',
                                prefixIcon:
                                    Icon(Icons.location_on_outlined, size: 20)),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _description,
                            maxLines: 2,
                            decoration: const InputDecoration(
                                labelText: 'Description (optional)',
                                prefixIcon:
                                    Icon(Icons.notes_outlined, size: 20)),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radius),
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Date',
                                  prefixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                      size: 20)),
                              child: Text(DateFormat.yMMMd().format(_date)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _paymentMethod,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Payment method',
                                prefixIcon:
                                    Icon(Icons.credit_card_outlined, size: 20)),
                            items: TransactionFields.paymentMethods
                                .map((p) =>
                                    DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _paymentMethod = v!),
                          ),
                          const SizedBox(height: 14),
                          _statusSelector(),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 600),
                        child: ReceiptPicker(
                          userId: widget.userId,
                          initialUrl: _receiptUrl,
                          onChanged: (url) => setState(() => _receiptUrl = url),
                        ),
                      ),
                      if (_type != 'Transfer') ...[
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          duration: const Duration(milliseconds: 650),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title:
                                const Text('Simulate new device / new login'),
                            subtitle: const Text(
                                'For demonstrating fraud-risk scoring',
                                style: TextStyle(fontSize: 11)),
                            value: _simulateNewDevice,
                            onChanged: (v) =>
                                setState(() => _simulateNewDevice = v),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 700),
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: saving ? null : _save,
                            style: FilledButton.styleFrom(
                                backgroundColor: AppTokens.brand),
                            child: saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text(_isEditing
                                    ? 'Save changes'
                                    : 'Add transaction'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
    );
  }

  Widget _typeSelector() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _typeChoices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = _typeChoices[i];
          final selected = _type == t;
          final color = TransactionTypeStyle.colorOf(t);
          return ChoiceChip(
            label: Text(t, style: const TextStyle(fontSize: 12.5)),
            avatar: Icon(TransactionTypeStyle.iconOf(t),
                size: 15, color: selected ? Colors.white : color),
            selected: selected,
            onSelected: (_) => setState(() => _type = t),
            selectedColor: color,
            labelStyle: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
            side: BorderSide(
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant),
          );
        },
      ),
    );
  }

  Widget _accountDropdown(List<AccountModel> accounts, String label,
      String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: accounts.any((a) => a.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              const Icon(Icons.account_balance_wallet_outlined, size: 20)),
      items: [
        for (final a in accounts)
          DropdownMenuItem(value: a.id, child: Text(a.accountName)),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _categoryField() {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radius),
      onTap: _pickCategory,
      child: InputDecorator(
        decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(Icons.category_outlined, size: 20)),
        child: Row(
          children: [
            Icon(TransactionCategoryStyle.iconOf(_category), size: 16),
            const SizedBox(width: 8),
            Text(_category),
          ],
        ),
      ),
    );
  }

  Widget _adjustmentDirection() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
            value: true, label: Text('Increase'), icon: Icon(Icons.add)),
        ButtonSegment(
            value: false, label: Text('Decrease'), icon: Icon(Icons.remove)),
      ],
      selected: {_adjustmentIncrease},
      onSelectionChanged: (s) => setState(() => _adjustmentIncrease = s.first),
    );
  }

  Widget _statusSelector() {
    return Wrap(
      spacing: 8,
      children: [
        for (final s in TransactionFields.statuses)
          ChoiceChip(
            label: Text(s, style: const TextStyle(fontSize: 12)),
            selected: _status == s,
            onSelected: (_) => setState(() => _status = s),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
