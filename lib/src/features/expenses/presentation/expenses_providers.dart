import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
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

/// Resolves the user's single personal group (D40). Primary: the
/// `users/{uid}.personalGroupId` pointer. Fallback (accounts created before
/// `bootstrapUser` was deployed, or a dangling pointer): the user's
/// `type == 'PERSONAL'` group in the already-watched group list.
Group? resolvePersonalGroup(User? user, List<Group>? groups) {
  if (user == null || groups == null) return null;

  final pointer = user.personalGroupId;
  if (pointer != null && pointer.isNotEmpty) {
    for (final group in groups) {
      if (group.id == pointer) return group;
    }
  }
  for (final group in groups) {
    if (group.type == 'PERSONAL' && group.ownerUid == user.id) return group;
  }
  return null;
}

/// The user's PERSONAL group, resolved by [resolvePersonalGroup].
final personalGroupProvider = Provider.autoDispose<Group?>((ref) {
  return resolvePersonalGroup(
    ref.watch(authControllerProvider).value,
    ref.watch(groupsListProvider).value,
  );
});

/// One-shot repair writes for D40, watched from `MainScreen` so it stays
/// alive while the user is signed in:
/// - backfills `users/{uid}.personalGroupId` when the fallback resolver found
///   a group but the pointer is unset/mismatched;
/// - provisions the personal group when none exists at all.
/// Each write is attempted at most once per uid per app run so a failed
/// write cannot loop; the stream providers converge once a write lands.
final personalGroupRepairProvider = Provider.autoDispose<void>((ref) {
  final user = ref.watch(authControllerProvider).value;
  final groups = ref.watch(groupsListProvider).value;
  if (user == null || groups == null) return;

  final repository = ref.read(groupsRepositoryProvider);
  final personal = resolvePersonalGroup(user, groups);

  if (personal != null) {
    // Idempotent merge — safe to retry on rebuilds while the user snapshot
    // catches up, so this write is not gated by the repair guard.
    if (personal.id != user.personalGroupId) {
      repository.setPersonalGroupId(user.id, personal.id);
    }
    return;
  }

  final hasPersonal = groups.any(
    (group) => group.type == 'PERSONAL' && group.ownerUid == user.id,
  );
  // Creating is not idempotent client-side, so it is gated: at most one
  // attempt per uid per app run.
  if (!hasPersonal && !_personalGroupRepairs.contains(user.id)) {
    _personalGroupRepairs.add(user.id);
    repository.createPersonalGroup(
      user.id,
      currency: user.defaultCurrency,
      creatorName: user.name,
    );
  }
});

final Set<String> _personalGroupRepairs = {};

/// Personal balance = all-time cash inflows - all-time personal expenses.
/// Derived in the client; there is no `users.balance` field.
final personalBalanceProvider = StreamProvider.autoDispose<double>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return Stream<double>.value(0);

  // Prefer the resolved group (D40 fallback covers unhealed pointers);
  // fall back to the raw pointer for the pre-repair frame.
  final personalGroupId =
      ref.watch(personalGroupProvider)?.id ?? user.personalGroupId;

  return _watchBalance(
    ref.watch(cashInflowRepositoryProvider),
    ref.watch(expensesRepositoryProvider),
    personalGroupId,
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
