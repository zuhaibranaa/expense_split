import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/expense_model.dart';
import '../data/expenses_repository.dart';

final expenseDateRangeFilterProvider =
    StateProvider.family<DateTimeRange?, int>((ref, groupId) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      return DateTimeRange(start: startOfMonth, end: endOfMonth);
    });

final expenseUserFilterProvider = StateProvider.family<int?, int>(
  (ref, groupId) => null,
);

final unfilteredExpensesFutureProvider = FutureProvider.family
    .autoDispose<List<Expense>, int>((ref, groupId) async {
      final repository = ref.watch(expensesRepositoryProvider);
      return repository.getExpenses(groupId); // No filters
    });

final minimizeDebtsProvider = StateProvider.family<bool, int>(
  (ref, groupId) => true,
);
