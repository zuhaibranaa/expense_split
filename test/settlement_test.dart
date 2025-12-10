import 'package:flutter_test/flutter_test.dart';
import 'package:settle_up_clone/src/features/expenses/domain/balance_calculator.dart';
import 'package:settle_up_clone/src/features/expenses/domain/expense_model.dart';
import 'package:settle_up_clone/src/features/people/domain/member_model.dart';

void main() {
  group('Settlement Tests', () {
    test('Partial settlement reduces debt correctly', () {
      // Setup Members
      final memberA = Member(id: 1, name: 'Alice', groupId: 1);
      final memberB = Member(id: 2, name: 'Bob', groupId: 1);
      final members = [memberA, memberB];

      // Setup Expense: Alice pays $100, split equally
      final expense1 = Expense(
        id: 1,
        description: 'Dinner',
        amount: 100,
        payerId: memberA.id,
        category: 'Food',
        groupId: 1,
        date: DateTime.now(),
        splits: [
          ExpenseSplit(id: 1, memberId: memberA.id, amount: 50),
          ExpenseSplit(id: 2, memberId: memberB.id, amount: 50),
        ],
      );

      // Verify initial balance
      var transfers = BalanceCalculator.calculateBalances([expense1], members);
      expect(transfers.length, 1);
      expect(transfers[0].fromMemberId, memberB.id); // Bob owes
      expect(transfers[0].toMemberId, memberA.id);   // Alice
      expect(transfers[0].amount, 50.0);

      // Settlement: Bob pays Alice $20
      final settlement = Expense(
        id: 2,
        description: 'Payment',
        amount: 20,
        payerId: memberB.id,
        category: 'Payment',
        groupId: 1,
        date: DateTime.now(),
        isSettlement: true,
        splits: [
          ExpenseSplit(id: 3, memberId: memberA.id, amount: 20),
        ],
      );

      // Verify updated balance
      transfers = BalanceCalculator.calculateBalances([expense1, settlement], members);
      expect(transfers.length, 1);
      expect(transfers[0].fromMemberId, memberB.id);
      expect(transfers[0].toMemberId, memberA.id);
      expect(transfers[0].amount, 30.0); // 50 - 20 = 30
    });

    test('Full settlement clears debt', () {
      final memberA = Member(id: 1, name: 'Alice', groupId: 1);
      final memberB = Member(id: 2, name: 'Bob', groupId: 1);
      final members = [memberA, memberB];

      final expense1 = Expense(
        id: 1,
        description: 'Dinner',
        amount: 100,
        payerId: memberA.id,
        category: 'Food',
        groupId: 1,
        date: DateTime.now(),
        splits: [
          ExpenseSplit(id: 1, memberId: memberA.id, amount: 50),
          ExpenseSplit(id: 2, memberId: memberB.id, amount: 50),
        ],
      );

      // Settlement: Bob pays Alice $50
      final settlement = Expense(
        id: 2,
        description: 'Full Payment',
        amount: 50,
        payerId: memberB.id,
        category: 'Payment',
        groupId: 1,
        date: DateTime.now(),
        isSettlement: true,
        splits: [
          ExpenseSplit(id: 3, memberId: memberA.id, amount: 50),
        ],
      );

      final transfers = BalanceCalculator.calculateBalances([expense1, settlement], members);
      expect(transfers, isEmpty); // Should be settled up
    });
    
    test('Overpayment reverses debt direction', () {
       final memberA = Member(id: 1, name: 'Alice', groupId: 1);
      final memberB = Member(id: 2, name: 'Bob', groupId: 1);
      final members = [memberA, memberB];

      final expense1 = Expense(
        id: 1,
        description: 'Dinner',
        amount: 100,
        payerId: memberA.id,
        category: 'Food',
        groupId: 1,
        date: DateTime.now(),
        splits: [
          ExpenseSplit(id: 1, memberId: memberA.id, amount: 50),
          ExpenseSplit(id: 2, memberId: memberB.id, amount: 50),
        ],
      );

      // Settlement: Bob pays Alice $60 (Overpay by $10)
      final settlement = Expense(
        id: 2,
        description: 'Overpayment',
        amount: 60,
        payerId: memberB.id,
        category: 'Payment',
        groupId: 1,
        date: DateTime.now(),
        isSettlement: true,
        splits: [
          ExpenseSplit(id: 3, memberId: memberA.id, amount: 60),
        ],
      );

      final transfers = BalanceCalculator.calculateBalances([expense1, settlement], members);
      expect(transfers.length, 1);
      expect(transfers[0].fromMemberId, memberA.id); // Alice owes Bob now
      expect(transfers[0].toMemberId, memberB.id);
      expect(transfers[0].amount, 10.0);
    });
  });
}
