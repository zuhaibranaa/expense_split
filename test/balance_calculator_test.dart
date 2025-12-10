import 'package:flutter_test/flutter_test.dart';
import 'package:settle_up_clone/src/features/expenses/domain/balance_calculator.dart';
import 'package:settle_up_clone/src/shared/data/database/database.dart';

void main() {
  group('BalanceCalculator', () {
    // Helpers to create dummy data
    Member createMember(int id, String name) {
      return Member(id: id, groupId: 1, name: name);
    }

    ExpenseWithSplits createExpense({
      required int id,
      required int payerId,
      required double amount,
      required List<int> splitMemberIds,
    }) {
      final expense = Expense(
        id: id,
        groupId: 1,
        description: 'Test',
        amount: amount,
        payerId: payerId,
        date: DateTime.now(),
      );

      final splits = splitMemberIds.map((mid) {
        return ExpenseSplit(
          id: id * 100 + mid, // Fake unique ID
          expenseId: id,
          memberId: mid,
          amount: amount / splitMemberIds.length,
        );
      }).toList();

      return ExpenseWithSplits(expense: expense, splits: splits);
    }

    test('Simple Split: Alice pays \$20 split with Bob', () {
      final alice = createMember(1, 'Alice');
      final bob = createMember(2, 'Bob');
      
      final expense = createExpense(
        id: 1, 
        payerId: alice.id, 
        amount: 20.0, 
        splitMemberIds: [alice.id, bob.id]
      );

      final transfers = BalanceCalculator.calculateBalances(
        [expense], 
        [alice, bob]
      );

      // Expect: Bob pays Alice $10
      expect(transfers.length, 1);
      expect(transfers.first.fromMemberId, bob.id);
      expect(transfers.first.toMemberId, alice.id);
      expect(transfers.first.amount, 10.0);
    });

    test('Multi Payer: Alice pays \$20, Bob pays \$10. Both split.', () {
      final alice = createMember(1, 'Alice');
      final bob = createMember(2, 'Bob');

      // Alice pays $20 (Split: Alice $10, Bob $10)
      // Net: Alice +10, Bob -10
      final exp1 = createExpense(
        id: 1, 
        payerId: alice.id, 
        amount: 20.0, 
        splitMemberIds: [alice.id, bob.id]
      );

      // Bob pays $10 (Split: Alice $5, Bob $5)
      // Net: Bob +5, Alice -5
      final exp2 = createExpense(
        id: 2, 
        payerId: bob.id, 
        amount: 10.0, 
        splitMemberIds: [alice.id, bob.id]
      );

      // Total Net:
      // Alice: +10 - 5 = +5
      // Bob: -10 + 5 = -5
      // Result: Bob pays Alice $5

      final transfers = BalanceCalculator.calculateBalances(
        [exp1, exp2], 
        [alice, bob]
      );

      expect(transfers.length, 1);
      final t = transfers.first;
      expect(t.fromMemberId, bob.id);
      expect(t.toMemberId, alice.id);
      expect(t.amount, 5.0);
    });

    test('Complex: A pays 30 (A,B,C). B pays 30 (A,B,C). C pays nothing.', () {
      final a = createMember(1, 'A');
      final b = createMember(2, 'B');
      final c = createMember(3, 'C');

      // Exp 1: A pays 30. Split 10 each.
      // A: +20, B: -10, C: -10
      final exp1 = createExpense(id: 1, payerId: a.id, amount: 30, splitMemberIds: [a.id, b.id, c.id]);

      // Exp 2: B pays 30. Split 10 each.
      // A: -10, B: +20, C: -10
      final exp2 = createExpense(id: 2, payerId: b.id, amount: 30, splitMemberIds: [a.id, b.id, c.id]);

      // Total:
      // A: +10
      // B: +10
      // C: -20
      // Result: C pays A 10, C pays B 10 (or similar combination)

      final transfers = BalanceCalculator.calculateBalances(
        [exp1, exp2], 
        [a, b, c]
      );

      expect(transfers.length, 2);
      
      // Verify total debt covered
      final totalTransferred = transfers.fold(0.0, (sum, t) => sum + t.amount);
      expect(totalTransferred, 20.0);
      
      // Verify Payers/Payees
      final payers = transfers.map((t) => t.fromMemberId).toSet();
      final payees = transfers.map((t) => t.toMemberId).toSet();
      
      expect(payers, {c.id}); // Only C pays
      expect(payees.contains(a.id), true); 
      expect(payees.contains(b.id), true);
    });
  });
}
