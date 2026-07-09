import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../features/accounts/data/account_providers.dart';
import '../../features/transactions/data/transaction_providers.dart';
import '../../models/account_model.dart';
import '../../models/transaction_model.dart';
import '../../utils/constants.dart';

/// CSV statement import (guide section 3.4).
///
/// Expected columns (header row, any order):
///   date, account_name, type, category, amount, description
///
/// The screen reads each row, validates the required fields, matches the
/// account by name, detects duplicates against existing + in-batch rows,
/// previews everything, then saves the approved rows through
/// [TransactionRepository.create] so fraud scoring and budget alerts still
/// run on each imported transaction.
///
/// A paste box + "Load sample" is used instead of a native file picker so the
/// feature works offline without adding new packages. Paste the contents of a
/// .csv file (e.g. sample_data/sample_transactions.csv) into the box.
class ImportCsvScreen extends ConsumerStatefulWidget {
  final String userId;
  const ImportCsvScreen({super.key, required this.userId});

  @override
  ConsumerState<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

enum RowStatus { newRow, duplicate, invalid }

class _ParsedRow {
  final int line; // 1-based source line for user feedback
  final DateTime? date;
  final String accountName;
  final String? accountId;
  final String type;
  final String category;
  final double amount;
  final String description;
  RowStatus status;
  String reason;

  _ParsedRow({
    required this.line,
    required this.date,
    required this.accountName,
    required this.accountId,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.status,
    this.reason = '',
  });
}

const _sampleCsv = '''date,account_name,type,category,amount,description
2026-07-01,MTN MoMo,Income,Salary,150000,Monthly salary
2026-07-02,MTN MoMo,Expense,Airtime,1000,Airtime purchase
2026-07-03,MTN MoMo,Expense,Food,5000,Market shopping
2026-07-04,UBA,Expense,Transport,2500,Taxi fare
2026-07-05,UBA,Expense,Rent,60000,Monthly rent payment''';

class _ImportCsvScreenState extends ConsumerState<ImportCsvScreen> {
  final _csv = TextEditingController();

  List<_ParsedRow> _parsed = [];
  bool _parsing = false;
  bool _importing = false;
  bool _skipDuplicates = true;
  String? _error;

  int get _newCount =>
      _parsed.where((r) => r.status == RowStatus.newRow).length;
  int get _dupCount =>
      _parsed.where((r) => r.status == RowStatus.duplicate).length;
  int get _invalidCount =>
      _parsed.where((r) => r.status == RowStatus.invalid).length;

  int get _importableCount =>
      _skipDuplicates ? _newCount : _newCount + _dupCount;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final text = _csv.text.trim();
    if (text.isEmpty) {
      setState(
          () => _error = 'Paste CSV content first (or tap "Load sample").');
      return;
    }
    setState(() {
      _parsing = true;
      _error = null;
      _parsed = [];
    });

    try {
      // Load the user's accounts (to match account_name) and existing
      // transactions (to detect duplicates) once.
      final accounts = await ref
          .read(accountRepositoryProvider)
          .watchAccounts(widget.userId)
          .first;
      final existing =
          await ref.read(transactionRepositoryProvider).fetchAll(widget.userId);

      final byName = <String, AccountModel>{
        for (final a in accounts) a.accountName.trim().toLowerCase(): a,
      };

      final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      // csv 8.x: Csv().decode() returns List<List<dynamic>>. Keep fields as
      // strings (dynamicTyping: false) so we validate amounts/dates ourselves.
      final rows = Csv(
        autoDetect: false,
        skipEmptyLines: true,
        dynamicTyping: false,
      ).decode(normalized);

      if (rows.isEmpty) {
        setState(() => _error = 'No rows found in the CSV.');
        return;
      }

      // Resolve columns from the header row; fall back to a fixed order.
      final header =
          rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      final hasHeader = header.contains('date') && header.contains('amount');
      int col(String name, int fallback) {
        final i = header.indexOf(name);
        return i >= 0 ? i : fallback;
      }

      final dateCol = col('date', 0);
      final accCol = col('account_name', 1);
      final typeCol = col('type', 2);
      final catCol = col('category', 3);
      final amtCol = col('amount', 4);
      final descCol = col('description', 5);

      final dataRows = hasHeader ? rows.skip(1).toList() : rows;

      // Duplicate keys already in the database.
      final existingKeys = existing.map(_keyFor).toSet();
      final batchKeys = <String>{};

      final parsed = <_ParsedRow>[];
      var lineNo = hasHeader ? 1 : 0;

      for (final raw in dataRows) {
        lineNo++;
        String cell(int i) =>
            (i >= 0 && i < raw.length) ? raw[i].toString().trim() : '';

        final rowIsBlank = raw.every((c) => c.toString().trim().isEmpty);
        if (rowIsBlank) continue;

        final dateStr = cell(dateCol);
        final accName = cell(accCol);
        final typeStr = cell(typeCol);
        final catStr = cell(catCol);
        final amtStr = cell(amtCol);
        final descStr = cell(descCol);

        final date = _tryParseDate(dateStr);
        final normalizedType = _normalizeType(typeStr);
        final amount = double.tryParse(amtStr.replaceAll(',', ''));
        final account = byName[accName.toLowerCase()];
        final category = catStr.isEmpty ? 'Other' : catStr;

        // Validation, most specific reason first.
        String? reason;
        if (date == null) {
          reason = 'Invalid/blank date "$dateStr" (use YYYY-MM-DD).';
        } else if (accName.isEmpty) {
          reason = 'Missing account_name.';
        } else if (account == null) {
          reason = 'No account named "$accName" — create it first.';
        } else if (normalizedType == null) {
          reason = 'Type must be Income or Expense (got "$typeStr").';
        } else if (amount == null || amount <= 0) {
          reason = 'Amount must be a number greater than 0 (got "$amtStr").';
        }

        if (reason != null) {
          parsed.add(_ParsedRow(
            line: lineNo,
            date: date,
            accountName: accName,
            accountId: account?.id,
            type: normalizedType ?? typeStr,
            category: category,
            amount: amount ?? 0,
            description: descStr,
            status: RowStatus.invalid,
            reason: reason,
          ));
          continue;
        }

        final key = _key(account!.id, date!, amount!, descStr);
        final isDuplicate =
            existingKeys.contains(key) || batchKeys.contains(key);
        batchKeys.add(key);

        parsed.add(_ParsedRow(
          line: lineNo,
          date: date,
          accountName: accName,
          accountId: account.id,
          type: normalizedType!,
          category: category,
          amount: amount,
          description: descStr,
          status: isDuplicate ? RowStatus.duplicate : RowStatus.newRow,
          reason: isDuplicate ? 'Matches an existing transaction.' : '',
        ));
      }

      setState(() {
        _parsed = parsed;
        if (parsed.isEmpty) _error = 'No data rows found in the CSV.';
      });
    } catch (e) {
      setState(() => _error = 'Could not parse CSV: $e');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _import() async {
    final toImport = _parsed
        .where((r) =>
            r.status == RowStatus.newRow ||
            (!_skipDuplicates && r.status == RowStatus.duplicate))
        .toList();

    if (toImport.isEmpty) {
      Fluttertoast.showToast(msg: 'Nothing to import.');
      return;
    }

    setState(() => _importing = true);
    var saved = 0;
    try {
      final txRepo = ref.read(transactionRepositoryProvider);
      for (final r in toImport) {
        await txRepo.create(
          userId: widget.userId,
          accountId: r.accountId!,
          type: r.type,
          category: r.category,
          amount: r.amount,
          description: r.description,
          paymentMethod: '',
          transactionDate: r.date!,
        );
        saved++;
      }
      if (saved > 0) {
        await txRepo.logActivity(
            widget.userId, 'Imported $saved transaction(s) via CSV');
      }
      if (mounted) {
        Fluttertoast.showToast(msg: 'Imported $saved transaction(s).');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        Fluttertoast.showToast(msg: 'Import stopped after $saved: $e');
      }
    }
  }

  // ---- helpers ----

  String _keyFor(TransactionModel t) =>
      _key(t.accountId, t.transactionDate, t.amount, t.description);

  String _key(String accountId, DateTime date, double amount, String desc) {
    final d =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '$accountId|$d|${amount.toStringAsFixed(0)}|${desc.trim().toLowerCase()}';
  }

  DateTime? _tryParseDate(String s) {
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    // Fallback: DD/MM/YYYY or DD-MM-YYYY.
    final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(s);
    if (m != null) {
      final day = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final year = int.parse(m.group(3)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  /// CSV import supports Income and Expense only. Transfers need a
  /// destination account, which the CSV format does not carry.
  String? _normalizeType(String s) {
    switch (s.trim().toLowerCase()) {
      case 'income':
        return 'Income';
      case 'expense':
        return 'Expense';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import CSV'),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste the contents of a CSV statement below. Columns: '
              'date, account_name, type, category, amount, description.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _csv,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                hintText:
                    'date,account_name,type,category,amount,description\n...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.card,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _parsing || _importing
                      ? null
                      : () => setState(() => _csv.text = _sampleCsv),
                  icon: const Icon(Icons.description, size: 18),
                  label: const Text('Load sample'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _parsing || _importing ? null : _parse,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  icon: _parsing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.fact_check,
                          color: Colors.white, size: 18),
                  label: const Text('Preview / Validate',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            if (_parsed.isNotEmpty) ...[
              const SizedBox(height: 16),
              _summaryBar(),
              const SizedBox(height: 8),
              if (_dupCount > 0)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Skip duplicates',
                      style: TextStyle(fontSize: 13)),
                  value: _skipDuplicates,
                  activeThumbColor: AppColors.primary,
                  onChanged: _importing
                      ? null
                      : (v) => setState(() => _skipDuplicates = v),
                ),
              const SizedBox(height: 4),
              ..._parsed.map(_rowTile),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _importing || _importableCount == 0 ? null : _import,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _importing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Import $_importableCount transaction(s)',
                        style: const TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryBar() {
    Widget chip(String label, int count, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count $label',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('new', _newCount, AppColors.success),
        chip('duplicate', _dupCount, AppColors.warning),
        chip('invalid', _invalidCount, AppColors.danger),
      ],
    );
  }

  Widget _rowTile(_ParsedRow r) {
    final Color color;
    final IconData icon;
    switch (r.status) {
      case RowStatus.newRow:
        color = AppColors.success;
        icon = Icons.check_circle;
        break;
      case RowStatus.duplicate:
        color = AppColors.warning;
        icon = Icons.copy;
        break;
      case RowStatus.invalid:
        color = AppColors.danger;
        icon = Icons.error;
        break;
    }
    final dateStr = r.date == null
        ? '—'
        : '${r.date!.year}-${r.date!.month.toString().padLeft(2, '0')}-${r.date!.day.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.description.isEmpty ? r.category : r.description} • ${formatFCFA(r.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Line ${r.line} • $dateStr • ${r.accountName} • ${r.type}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (r.reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(r.reason,
                        style: TextStyle(fontSize: 11, color: color)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
