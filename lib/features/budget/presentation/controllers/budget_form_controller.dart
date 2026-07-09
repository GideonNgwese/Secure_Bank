import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/budget_model.dart';
import '../../data/budget_providers.dart';

/// Drives every budget mutation: create, update, delete, duplicate, archive/
/// restore, reset-to-next-period. `AsyncData` = idle/succeeded, `AsyncLoading`
/// = writing, `AsyncError` = failed (UI shows the friendly message).
class BudgetFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return false;
    }
  }

  Future<bool> create(BudgetModel budget) =>
      _run(() => ref.read(budgetRepositoryProvider).create(budget));

  /// Named `updateBudget` (not `update`) — `update` collides with the base
  /// [AsyncNotifierBase.update] state-mutation method.
  Future<bool> updateBudget(BudgetModel budget) =>
      _run(() => ref.read(budgetRepositoryProvider).update(budget));

  Future<bool> delete(String id) =>
      _run(() => ref.read(budgetRepositoryProvider).delete(id));

  Future<bool> duplicate(BudgetModel budget, String newId) =>
      _run(() => ref.read(budgetRepositoryProvider).duplicate(budget, newId));

  Future<bool> setStatus(String id, String status) =>
      _run(() => ref.read(budgetRepositoryProvider).setStatus(id, status));

  Future<bool> resetToNextPeriod(BudgetModel budget) =>
      _run(() => ref.read(budgetRepositoryProvider).resetToNextPeriod(budget));
}

final budgetFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<BudgetFormController, void>(
        BudgetFormController.new);
