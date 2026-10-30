import 'package:equisplit/src/features/expenses/domain/balance_calculator.dart';
import 'package:equisplit/src/features/expenses/domain/expense_model.dart';
import 'package:equisplit/src/features/people/domain/member_model.dart';
import 'package:flutter_test/flutter_test.dart';

Member member(String id) =>
    Member(id: id, name: id.toUpperCase(), groupId: 'group-1');

Expense expense({
  required double amount,
  required String payerId,
  required Map<String, double> splits,
  Map<String, double> payments = const {},
}) {
  return Expense(
    id: 'expense-1',
    groupId: 'group-1',
    description: 'Test expense',
    amount: amount,
    category: 'General',
    payerId: payerId,
    date: DateTime(2026, 1, 1),
    splits: splits.entries
        .map((entry) => ExpenseSplit(memberId: entry.key, amount: entry.value))
        .toList(),
    payments: payments.entries
        .map(
          (entry) => ExpensePayment(memberId: entry.key, amount: entry.value),
        )
        .toList(),
  );
}

String describe(BalanceTransfer transfer) =>
    '${transfer.fromMemberId}->${transfer.toMemberId}:'
    '${transfer.amount.toStringAsFixed(2)}';

void main() {
  final members = [member('a'), member('b'), member('c')];

  group('calculateNetBalances', () {
    test('splits a single-payer expense equally', () {
      final transfers = BalanceCalculator.calculateNetBalances([
        expense(amount: 30, payerId: 'a', splits: {'a': 10, 'b': 10, 'c': 10}),
      ], members);

      expect(
        transfers.map(describe),
        containsAll(<String>['b->a:10.00', 'c->a:10.00']),
      );
      expect(transfers.length, 2);
    });

    test('uses the payments array for multiple payers', () {
      final transfers = BalanceCalculator.calculateNetBalances([
        expense(
          amount: 30,
          payerId: 'a',
          splits: {'a': 10, 'b': 10, 'c': 10},
          payments: {'a': 20, 'b': 10},
        ),
      ], members);

      expect(transfers.map(describe), ['c->a:10.00']);
    });

    test('keeps cent-level rounding stable', () {
      final transfers = BalanceCalculator.calculateNetBalances([
        expense(
          amount: 10,
          payerId: 'a',
          splits: {'a': 3.33, 'b': 3.33, 'c': 3.34},
        ),
      ], members);

      expect(transfers.map(describe).toSet(), {'b->a:3.33', 'c->a:3.34'});
    });

    test('returns no transfers when everyone is settled', () {
      final transfers = BalanceCalculator.calculateNetBalances([
        expense(amount: 30, payerId: 'a', splits: {'a': 30}),
      ], members);

      expect(transfers, isEmpty);
    });
  });

  group('calculateDirectDebts', () {
    test('keeps pairwise debts without transitive simplification', () {
      final transfers = BalanceCalculator.calculateDirectDebts([
        expense(amount: 30, payerId: 'a', splits: {'a': 10, 'b': 10, 'c': 10}),
      ], members);

      expect(transfers.map(describe).toSet(), {'b->a:10.00', 'c->a:10.00'});
    });

    test('nets opposing debts between two members', () {
      final transfers = BalanceCalculator.calculateDirectDebts(
        [
          expense(amount: 20, payerId: 'a', splits: {'a': 10, 'b': 10}),
          expense(amount: 6, payerId: 'b', splits: {'a': 3, 'b': 3}),
        ],
        [member('a'), member('b')],
      );

      expect(transfers.map(describe), ['b->a:7.00']);
    });
  });
}
