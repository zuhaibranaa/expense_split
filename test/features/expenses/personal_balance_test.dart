import 'package:equisplit/src/features/cash_inflows/domain/cash_inflow_model.dart';
import 'package:equisplit/src/features/expenses/domain/expense_model.dart';
import 'package:equisplit/src/features/expenses/presentation/expenses_providers.dart';
import 'package:flutter_test/flutter_test.dart';

CashInflow inflow(double amount) => CashInflow(
  id: 'inflow-$amount',
  userId: 'uid-1',
  amount: amount,
  currencyCode: 'USD',
  category: 'Income',
  description: 'Income',
  date: DateTime(2026, 1, 1),
);

Expense expense(double amount, {bool isSettlement = false}) => Expense(
  id: 'expense-$amount-$isSettlement',
  groupId: 'personal-group',
  description: 'Expense',
  amount: amount,
  category: 'General',
  payerId: 'uid-1',
  date: DateTime(2026, 1, 1),
  isSettlement: isSettlement,
);

void main() {
  group('calculatePersonalBalance', () {
    test('is inflows minus personal expenses', () {
      final balance = calculatePersonalBalance(
        [inflow(100), inflow(250.5)],
        [expense(40.25), expense(10)],
      );

      expect(balance, 300.25);
    });

    test('ignores settlement entries', () {
      final balance = calculatePersonalBalance(
        [inflow(100)],
        [expense(30), expense(70, isSettlement: true)],
      );

      expect(balance, 70);
    });

    test('is zero when there is no activity', () {
      expect(calculatePersonalBalance([], []), 0);
    });

    test('can be negative when expenses exceed inflows', () {
      expect(calculatePersonalBalance([inflow(50)], [expense(80)]), -30);
    });
  });
}
