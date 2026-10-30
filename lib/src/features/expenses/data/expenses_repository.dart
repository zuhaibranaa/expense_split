import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_converters.dart';
import '../../../core/firebase/firestore_refs.dart';
import '../../groups/data/groups_repository.dart';
import '../domain/expense_model.dart';
import '../presentation/expenses_providers.dart';

class ExpensesRepository {
  ExpensesRepository(this._refs, this._auth);

  final FirestoreRefs _refs;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  Stream<List<Expense>> watchExpenses(
    String groupId, {
    DateTime? startDate,
    DateTime? endDate,
    String? memberId,
  }) {
    return _query(
      groupId,
      startDate: startDate,
      endDate: endDate,
      memberId: memberId,
    ).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Expense.fromDoc(groupId, doc))
          .toList(growable: false),
    );
  }

  Future<List<Expense>> getExpenses(
    String groupId, {
    DateTime? startDate,
    DateTime? endDate,
    String? memberId,
  }) async {
    final snapshot = await _query(
      groupId,
      startDate: startDate,
      endDate: endDate,
      memberId: memberId,
    ).get();
    return snapshot.docs
        .map((doc) => Expense.fromDoc(groupId, doc))
        .toList(growable: false);
  }

  Query<Map<String, dynamic>> _query(
    String groupId, {
    DateTime? startDate,
    DateTime? endDate,
    String? memberId,
  }) {
    Query<Map<String, dynamic>> query = _refs.expenses(groupId);
    if (startDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfDay(startDate)),
      );
    }
    if (endDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(endDate)),
      );
    }
    if (memberId != null && memberId.isNotEmpty) {
      query = query.where('memberIds', arrayContains: memberId);
    }
    return query.orderBy('date', descending: true);
  }

  Future<void> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String payerId,
    String payerName = '',
    required String category,
    required DateTime date,
    required Map<String, double> splits,
    Map<String, double>? payments,
    bool isSettlement = false,
  }) async {
    if (description.trim().isEmpty) {
      throw ArgumentError('Description cannot be empty.');
    }
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    if (splits.isEmpty) {
      throw ArgumentError('Select at least one person to split with.');
    }

    final memberIds = Expense.buildMemberIds(
      payerId: payerId,
      splits: splits,
      payments: payments,
    );

    await _refs.expenses(groupId).add({
      'description': description.trim(),
      'amount': roundMoney(amount),
      'category': category,
      'payerId': payerId,
      'payerName': payerName,
      'date': Timestamp.fromDate(date),
      'isSettlement': isSettlement,
      'splits': splits.entries
          .map(
            (entry) => {
              'memberId': entry.key,
              'amount': roundMoney(entry.value),
            },
          )
          .toList(growable: false),
      'payments': (payments ?? const <String, double>{}).entries
          .map(
            (entry) => {
              'memberId': entry.key,
              'amount': roundMoney(entry.value),
            },
          )
          .toList(growable: false),
      'memberIds': memberIds,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    required String userId,
    required String description,
    required double amount,
    required String payerId,
    String payerName = '',
    required String category,
    required DateTime date,
    required Map<String, double> splits,
    Map<String, double>? payments,
  }) async {
    final memberIds = Expense.buildMemberIds(
      payerId: payerId,
      splits: splits,
      payments: payments,
    );

    await _refs.expense(groupId, expenseId).update({
      'description': description.trim(),
      'amount': roundMoney(amount),
      'category': category,
      'payerId': payerId,
      'payerName': payerName,
      'date': Timestamp.fromDate(date),
      'splits': splits.entries
          .map(
            (entry) => {
              'memberId': entry.key,
              'amount': roundMoney(entry.value),
            },
          )
          .toList(growable: false),
      'payments': (payments ?? const <String, double>{}).entries
          .map(
            (entry) => {
              'memberId': entry.key,
              'amount': roundMoney(entry.value),
            },
          )
          .toList(growable: false),
      'memberIds': memberIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense({
    required String groupId,
    required String expenseId,
    required String userId,
  }) async {
    await _refs.expense(groupId, expenseId).delete();
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(
    ref.watch(firestoreRefsProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final expensesFutureProvider = AsyncNotifierProvider.autoDispose
    .family<ExpensesNotifier, List<Expense>, String>(ExpensesNotifier.new);

class ExpensesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Expense>, String> {
  StreamSubscription<List<Expense>>? _subscription;

  @override
  Future<List<Expense>> build(String groupId) async {
    ref.onDispose(() => _subscription?.cancel());

    final repo = ref.read(expensesRepositoryProvider);
    final dateRange = ref.watch(expenseDateRangeFilterProvider(groupId));
    final memberId = ref.watch(expenseUserFilterProvider(groupId));

    final stream = repo.watchExpenses(
      groupId,
      startDate: dateRange?.start,
      endDate: dateRange?.end,
      memberId: memberId,
    );
    final first = Completer<List<Expense>>();

    _subscription = stream.listen(
      (expenses) {
        if (!first.isCompleted) first.complete(expenses);
        state = AsyncValue.data(expenses);
      },
      onError: (Object error, StackTrace stack) {
        if (!first.isCompleted) first.completeError(error, stack);
        state = AsyncValue.error(error, stack);
      },
    );

    return first.future;
  }

  Future<void> createExpense({
    required String description,
    required double amount,
    required String payerId,
    required String category,
    required DateTime date,
    required Map<String, double> splits,
    Map<String, double>? payments,
    bool isSettlement = false,
  }) async {
    final repo = ref.read(expensesRepositoryProvider);
    await repo.createExpense(
      groupId: arg,
      description: description,
      amount: amount,
      payerId: payerId,
      payerName: _memberName(payerId),
      category: category,
      date: date,
      splits: splits,
      payments: payments,
      isSettlement: isSettlement,
    );
  }

  Future<void> updateExpense({
    required String expenseId,
    required String userId,
    required String description,
    required double amount,
    required String payerId,
    required String category,
    required DateTime date,
    required Map<String, double> splits,
    Map<String, double>? payments,
  }) async {
    final repo = ref.read(expensesRepositoryProvider);
    await repo.updateExpense(
      groupId: arg,
      expenseId: expenseId,
      userId: userId,
      description: description,
      amount: amount,
      payerId: payerId,
      payerName: _memberName(payerId),
      category: category,
      date: date,
      splits: splits,
      payments: payments,
    );
  }

  Future<void> deleteExpense(String expenseId, String userId) async {
    final repo = ref.read(expensesRepositoryProvider);
    final previousState = state;

    if (previousState.value != null) {
      state = AsyncValue.data(
        previousState.value!
            .where((expense) => expense.id != expenseId)
            .toList(growable: false),
      );
    }

    try {
      await repo.deleteExpense(
        groupId: arg,
        expenseId: expenseId,
        userId: userId,
      );
    } catch (error) {
      state = previousState;
      rethrow;
    }
  }

  String _memberName(String memberId) {
    final members = ref.read(groupMembersProvider(arg)).value;
    if (members == null) return '';
    for (final member in members) {
      if (member.id == memberId) return member.name;
    }
    return '';
  }
}
