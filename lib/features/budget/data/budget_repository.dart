import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/budget_model.dart';
import '../domain/budget_view.dart';

/// Owns `budgets` collection persistence. Spend is never written here —
/// it's always computed live from transactions (see [BudgetModel]'s doc
/// comment) — so this repository only ever touches the budget's own
/// configuration fields.
class BudgetRepository {
  final FirebaseFirestore _db;
  BudgetRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  Stream<List<BudgetModel>> watchAll(String userId) {
    return _db
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => BudgetModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> create(BudgetModel budget) =>
      _db.collection('budgets').doc(budget.id).set(budget.toMap());

  Future<void> update(BudgetModel budget) => _db
      .collection('budgets')
      .doc(budget.id)
      .set(budget.copyWith(updatedAt: DateTime.now()).toMap());

  Future<void> delete(String id) => _db.collection('budgets').doc(id).delete();

  Future<void> setStatus(String id, String status) =>
      _db.collection('budgets').doc(id).update({
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      });

  /// Quick action: "Duplicate Budget" — an exact copy under a new id, left
  /// for the user to tweak (dates, amount, etc).
  Future<BudgetModel> duplicate(BudgetModel budget, String newId) async {
    final copy = BudgetModel(
      id: newId,
      userId: budget.userId,
      name: '${budget.name} (Copy)',
      category: budget.category,
      budgetAmount: budget.budgetAmount,
      currency: budget.currency,
      period: budget.period,
      startDate: budget.startDate,
      endDate: budget.endDate,
      status: 'Active',
      color: budget.color,
      icon: budget.icon,
      notes: budget.notes,
      createdAt: DateTime.now(),
    );
    await create(copy);
    return copy;
  }

  /// Quick action: "Reset Budget" — rolls the date range forward to the next
  /// period of the same length, so a recurring budget doesn't need to be
  /// recreated by hand every month.
  Future<void> resetToNextPeriod(BudgetModel budget) async {
    final next = nextPeriodRange(budget);
    await update(budget.copyWith(
      startDate: next.start,
      endDate: next.end,
      status: 'Active',
    ));
  }
}
