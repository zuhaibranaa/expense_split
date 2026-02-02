import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/data/api_client.dart';
import '../domain/expense_model.dart';
// Needed if we reference Member

class ExpensesRepository {
  final ApiClient _api;

  ExpensesRepository(this._api);

  Future<void> createExpense({
    required int groupId,
    required String description,
    required double amount,
    required int payerId,
    required String category,
    required DateTime date,
    required Map<int, double> splits,
    Map<int, double>? payments,
    bool isSettlement = false,
  }) async {
    final splitsList = splits.entries
        .map((e) => {'member_id': e.key, 'amount': e.value})
        .toList();

    List<Map<String, dynamic>>? paymentsList;
    if (payments != null) {
      paymentsList = payments.entries
          .map((e) => {'member_id': e.key, 'amount': e.value})
          .toList();
    }

    await _api.post('/groups/$groupId/expenses/', {
      'description': description,
      'amount': amount,
      'payer_id': payerId,
      'category': category,
      'date': date.toIso8601String(),
      'is_settlement': isSettlement,
      'splits': splitsList,
      if (paymentsList != null) 'payments': paymentsList,
    });
  }

  Future<List<Expense>> getExpenses(int groupId) async {
    final List<dynamic> json = await _api.get('/groups/$groupId/expenses/');
    return json.map((e) => Expense.fromJson(e)).toList();
  }

  Future<void> updateExpense({
    required int groupId,
    required int expenseId,
    required int userId,
    required String description,
    required double amount,
    required int payerId,
    required String category,
    required DateTime date,
    required Map<int, double> splits,
    Map<int, double>? payments,
  }) async {
    final splitsList = splits.entries
        .map((e) => {'member_id': e.key, 'amount': e.value})
        .toList();

    List<Map<String, dynamic>>? paymentsList;
    if (payments != null) {
      paymentsList = payments.entries
          .map((e) => {'member_id': e.key, 'amount': e.value})
          .toList();
    }

    await _api.put('/expenses/$expenseId?user_id=$userId', {
      'description': description,
      'amount': amount,
      'payer_id': payerId,
      'category': category,
      'date': date.toIso8601String(),
      'splits': splitsList,
      if (paymentsList != null) 'payments': paymentsList,
    });
  }

  Future<void> deleteExpense(int expenseId, int userId) async {
    await _api.delete('/expenses/$expenseId?user_id=$userId');
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return ExpensesRepository(api);
});

final expensesFutureProvider = AsyncNotifierProvider.autoDispose
    .family<ExpensesNotifier, List<Expense>, int>(ExpensesNotifier.new);

class ExpensesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Expense>, int> {
  @override
  Future<List<Expense>> build(int arg) async {
    final repo = ref.read(expensesRepositoryProvider);
    return repo.getExpenses(arg);
  }

  Future<void> createExpense({
    required String description,
    required double amount,
    required int payerId,
    required String category,
    required DateTime date,
    required Map<int, double> splits,
    Map<int, double>? payments,
    bool isSettlement = false,
  }) async {
    final repo = ref.read(expensesRepositoryProvider);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.createExpense(
        groupId: arg,
        description: description,
        amount: amount,
        payerId: payerId,
        category: category,
        date: date,
        splits: splits,
        payments: payments,
        isSettlement: isSettlement,
      );
      return repo.getExpenses(arg);
    });
  }

  Future<void> updateExpense({
    required int expenseId,
    required int userId,
    required String description,
    required double amount,
    required int payerId,
    required String category,
    required DateTime date,
    required Map<int, double> splits,
    Map<int, double>? payments,
  }) async {
    final repo = ref.read(expensesRepositoryProvider);
    // Optimistic Update (Complex due to splits, but we can try basic fields if needed)
    // For now, let's just use refetch for safety as backend calculation is important?
    // Actually, local update is fine if we reconstruct Expense object.

    try {
      await repo.updateExpense(
        groupId: arg,
        expenseId: expenseId,
        userId: userId,
        description: description,
        amount: amount,
        payerId: payerId,
        category: category,
        date: date,
        splits: splits,
        payments: payments,
      );
      // Refetch to get consistent state
      state = await AsyncValue.guard(() => repo.getExpenses(arg));
    } catch (e) {
      // state = previousState; // If we didn't optimistic update, no need to revert, but we are reloading
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteExpense(int expenseId, int userId) async {
    final repo = ref.read(expensesRepositoryProvider);
    final previousState = state;

    // Optimistic Update
    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!.where((e) => e.id != expenseId).toList(),
      );
    }

    try {
      await repo.deleteExpense(expenseId, userId);
    } catch (e) {
      state = previousState;
      rethrow;
    }
  }
}
