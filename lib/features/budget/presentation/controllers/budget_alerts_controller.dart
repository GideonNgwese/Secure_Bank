import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/firestore_service.dart';

/// Runs the time-based budget alert checks (Ending Soon / Monthly Budget
/// Completed) once when the Budget screen opens — these aren't triggered by
/// a transaction write, so nothing else would ever check them. Deterministic
/// alert ids make this safe to call every time the screen loads.
class BudgetAlertsController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> checkTimeBasedAlerts(String userId) async {
    try {
      await FirestoreService().checkBudgetTimeBasedAlerts(userId);
    } catch (_) {
      // Best-effort — never block the screen on this failing.
    }
  }
}

final budgetAlertsControllerProvider =
    AutoDisposeAsyncNotifierProvider<BudgetAlertsController, void>(
        BudgetAlertsController.new);
