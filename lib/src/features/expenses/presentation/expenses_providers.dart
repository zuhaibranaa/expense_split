import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/expense_model.dart';
import '../data/expenses_repository.dart';
import '../../cash_inflows/data/cash_inflow_repository.dart';
import '../../cash_inflows/domain/cash_inflow_model.dart';

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

// Provider for fetching inflows with filter support
final inflowsListProvider = FutureProvider.autoDispose
    .family<List<CashInflow>, int>((ref, groupId) async {
      final dateRange = ref.watch(expenseDateRangeFilterProvider(groupId));
      return ref
          .watch(cashInflowRepositoryProvider)
          .getInflows(startDate: dateRange?.start, endDate: dateRange?.end);
    });
