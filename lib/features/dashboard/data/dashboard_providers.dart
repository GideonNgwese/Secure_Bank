import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/account_model.dart';
import '../../../models/transaction_model.dart';
import '../../../services/firestore_service.dart';
import '../domain/dashboard_data.dart';

/// Single FirestoreService instance for the dashboard feature.
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final dashboardAccountsProvider =
    StreamProvider.family<List<AccountModel>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).streamAccounts(userId);
});

final dashboardTransactionsProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).streamTransactions(userId);
});

/// Computed dashboard state, combining the account + transaction streams.
/// Emits loading/error/data so the UI can show skeletons / retry / content.
final dashboardDataProvider =
    Provider.family<AsyncValue<DashboardData>, String>((ref, userId) {
  final accounts = ref.watch(dashboardAccountsProvider(userId));
  final txs = ref.watch(dashboardTransactionsProvider(userId));

  return accounts.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (accs) => txs.when(
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
      data: (list) => AsyncValue.data(DashboardData.compute(accs, list)),
    ),
  );
});
