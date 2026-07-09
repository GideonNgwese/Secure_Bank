import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/report_export_controller.dart';

/// Bottom sheet offering Export PDF / Export CSV / Export Excel (coming
/// soon — kept visible but disabled so the option is discoverable and
/// future-ready without a half-built Excel writer shipping today).
void showExportActionsSheet(
    BuildContext context, WidgetRef ref, String userId, String userName) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4))),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Export report',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined,
                color: AppTokens.danger),
            title: const Text('Export as PDF'),
            subtitle: const Text(
                'Branded statement-style report — share or print',
                style: TextStyle(fontSize: 11)),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final messenger = ScaffoldMessenger.of(context);
              final ok = await ref
                  .read(reportExportControllerProvider.notifier)
                  .exportPdf(userId: userId, userName: userName);
              if (!ok && context.mounted) {
                messenger.showSnackBar(const SnackBar(
                    content: Text('Could not generate the PDF.')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined,
                color: AppTokens.success),
            title: const Text('Export as CSV'),
            subtitle: const Text('Copies the full report to your clipboard',
                style: TextStyle(fontSize: 11)),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final messenger = ScaffoldMessenger.of(context);
              final ok = await ref
                  .read(reportExportControllerProvider.notifier)
                  .exportCsv(userId);
              if (context.mounted) {
                messenger.showSnackBar(SnackBar(
                    content: Text(ok
                        ? 'CSV copied to clipboard'
                        : 'Could not generate the CSV.')));
              }
            },
          ),
          ListTile(
            enabled: false,
            leading: Icon(Icons.grid_on_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            title: const Text('Export as Excel'),
            subtitle: const Text('Coming soon', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
