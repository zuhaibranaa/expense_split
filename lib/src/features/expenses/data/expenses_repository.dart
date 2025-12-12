import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/data/api_client.dart';
import '../domain/expense_model.dart';
import '../../people/domain/member_model.dart'; // Needed if we reference Member

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
    bool isSettlement = false,
  }) async {
    final splitsList = splits.entries
        .map((e) => {'member_id': e.key, 'amount': e.value})
        .toList();

    await _api.post('/groups/$groupId/expenses/', {
      'description': description,
      'amount': amount,
      'payer_id': payerId,
      'category': category,
      'date': date.toIso8601String(),
      'is_settlement': isSettlement,
      'splits': splitsList,
    });
  }

  Future<List<Expense>> getExpenses(int groupId) async {
    final List<dynamic> json = await _api.get('/groups/$groupId/expenses/');
    return json.map((e) => Expense.fromJson(e)).toList();
  }

  Future<List<Expense>> getExpensesList(int groupId) async {
    final jsonList = await _api.get('/groups/$groupId/expenses/');
    return (jsonList as List).map((e) => Expense.fromJson(e)).toList();
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
  }) async {
    final splitsList = splits.entries
        .map((e) => {'member_id': e.key, 'amount': e.value})
        .toList();

    await _api.put('/groups/$groupId/expenses/$expenseId?user_id=$userId', {
      'description': description,
      'amount': amount,
      'payer_id': payerId,
      'category': category,
      'date': date.toIso8601String(),
      'splits': splitsList,
    });
  }

  Future<void> deleteExpense(int groupId, int expenseId, int userId) async {
    await _api.delete('/groups/$groupId/expenses/$expenseId?user_id=$userId');
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return ExpensesRepository(api);
});

// Replaces watchGroupExpenses
final expensesStreamProvider = StreamProvider.autoDispose
    .family<List<Expense>, int>((ref, groupId) async* {
      final repo = ref.watch(expensesRepositoryProvider);
      yield await repo.getExpenses(groupId);
      await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
        yield await repo.getExpenses(groupId);
      }
    });
