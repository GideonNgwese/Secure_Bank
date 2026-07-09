import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/transaction_model.dart';
import '../../data/transaction_providers.dart';

/// Drives the Add/Edit Transaction save button and the detail screen's
/// delete action. `AsyncData` = idle/succeeded, `AsyncLoading` = writing,
/// `AsyncError` = failed (UI shows the friendly message via ref.listen).
class TransactionFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<T?> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final result = await action();
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return null;
    }
  }

  Future<TransactionModel?> create({
    required String userId,
    required String accountId,
    required String type,
    required String category,
    required double amount,
    String title = '',
    required String description,
    String currency = 'FCFA',
    String paymentMethod = '',
    String merchant = '',
    String location = '',
    String receiptUrl = '',
    String status = 'Completed',
    required DateTime transactionDate,
    bool simulateNewDevice = false,
  }) =>
      _run(() => ref.read(transactionRepositoryProvider).create(
            userId: userId,
            accountId: accountId,
            type: type,
            category: category,
            amount: amount,
            title: title,
            description: description,
            currency: currency,
            paymentMethod: paymentMethod,
            merchant: merchant,
            location: location,
            receiptUrl: receiptUrl,
            status: status,
            transactionDate: transactionDate,
            simulateNewDevice: simulateNewDevice,
          ));

  /// Named `updateTransaction` (not `update`) — `update` collides with the
  /// base [AsyncNotifierBase.update] state-mutation method.
  Future<TransactionModel?> updateTransaction({
    required TransactionModel original,
    required String accountId,
    required String type,
    required String category,
    required double amount,
    String title = '',
    required String description,
    String currency = 'FCFA',
    String paymentMethod = '',
    String merchant = '',
    String location = '',
    String receiptUrl = '',
    String status = 'Completed',
    required DateTime transactionDate,
    bool simulateNewDevice = false,
  }) =>
      _run(() => ref.read(transactionRepositoryProvider).update(
            original: original,
            accountId: accountId,
            type: type,
            category: category,
            amount: amount,
            title: title,
            description: description,
            currency: currency,
            paymentMethod: paymentMethod,
            merchant: merchant,
            location: location,
            receiptUrl: receiptUrl,
            status: status,
            transactionDate: transactionDate,
            simulateNewDevice: simulateNewDevice,
          ));

  Future<bool> createTransfer({
    required String userId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String description,
    required DateTime transactionDate,
    String currency = 'FCFA',
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(transactionRepositoryProvider).createTransfer(
            userId: userId,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            amount: amount,
            description: description,
            transactionDate: transactionDate,
            currency: currency,
          );
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return false;
    }
  }

  Future<bool> delete(TransactionModel tx) async {
    state = const AsyncLoading();
    try {
      await ref.read(transactionRepositoryProvider).delete(tx);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return false;
    }
  }
}

final transactionFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<TransactionFormController, void>(
        TransactionFormController.new);
