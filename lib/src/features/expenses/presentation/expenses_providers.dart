import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../cash_inflows/data/cash_inflow_repository.dart';
import '../../cash_inflows/domain/cash_inflow_model.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/domain/group_model.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_model.dart';

final expenseDateRangeFilterProvider =
    StateProvider.family<DateTimeRange?, String>((ref, groupId) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      return DateTimeRange(start: startOfMonth, end: endOfMonth);
    });

final expenseUserFilterProvider = StateProvider.family<String?, String>(
  (ref, groupId) => null,
);

final unfilteredExpensesFutureProvider = StreamProvider.autoDispose
    .family<List<Expense>, String>((ref, groupId) {
      return ref.watch(expensesRepositoryProvider).watchExpenses(groupId);
    });

final minimizeDebtsProvider = StateProvider.family<bool, String>(
  (ref, groupId) => true,
);

/// Personal-group expenses/inflows, filtered by the group's date range.
final inflowsListProvider = StreamProvider.autoDispose
    .family<List<CashInflow>, String>((ref, groupId) {
      final dateRange = ref.watch(expenseDateRangeFilterProvider(groupId));
      return ref
          .watch(cashInflowRepositoryProvider)
          .watchInflows(startDate: dateRange?.start, endDate: dateRange?.end);
    });

/// The user's PERSONAL group, resolved from `users/{uid}.personalGroupId`.
final personalGroupProvider = Provider.autoDispose<Group?>((ref) {
  final user = ref.watch(authControllerProvider).value;
  final groupId = user?.personalGroupId;
  if (groupId == null || groupId.isEmpty) return null;

  final groups = ref.watch(groupsListProvider).value;
  if (groups == null) return null;
  for (final group in groups) {
    if (group.id == groupId) return group;
  }
  return null;
});

/// Personal balance = all-time cash inflows - all-time personal expenses.
/// Derived in the client; there is no `users.balance` field.
final personalBalanceProvider = StreamProvider.autoDispose<double>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return Stream<double>.value(0);

  return _watchBalance(
    ref.watch(cashInflowRepositoryProvider),
    ref.watch(expensesRepositoryProvider),
    user.personalGroupId,
  );
});

/// Pure arithmetic behind [personalBalanceProvider]. Settlements are transfers
/// between members and never change the personal balance.
double calculatePersonalBalance(
  List<CashInflow> inflows,
  List<Expense> expenses,
) {
  final inflowTotal = inflows.fold<double>(
    0,
    (total, inflow) => total + inflow.amount,
  );
  final expenseTotal = expenses
      .where((expense) => !expense.isSettlement)
      .fold<double>(0, (total, expense) => total + expense.amount);
  return inflowTotal - expenseTotal;
}

Stream<double> _watchBalance(
  CashInflowRepository inflowRepository,
  ExpensesRepository expensesRepository,
  String? personalGroupId,
) {
  late StreamController<double> controller;
  StreamSubscription<List<CashInflow>>? inflowSubscription;
  StreamSubscription<List<Expense>>? expenseSubscription;
  var inflows = <CashInflow>[];
  var expenses = <Expense>[];

  void emit() {
    controller.add(calculatePersonalBalance(inflows, expenses));
  }

  controller = StreamController<double>(
    onListen: () {
      inflowSubscription = inflowRepository.watchInflows().listen((data) {
        inflows = data;
        emit();
      });
      final expenseStream = personalGroupId == null
          ? Stream<List<Expense>>.value(const [])
          : expensesRepository.watchExpenses(personalGroupId);
      expenseSubscription = expenseStream.listen((data) {
        expenses = data;
        emit();
      });
    },
    onCancel: () async {
      await inflowSubscription?.cancel();
      await expenseSubscription?.cancel();
    },
  );

  return controller.stream;
}
