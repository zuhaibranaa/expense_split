import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equisplit/src/features/auth/domain/user_model.dart';
import 'package:equisplit/src/features/cash_inflows/domain/cash_inflow_model.dart';
import 'package:equisplit/src/features/categories/domain/category_model.dart';
import 'package:equisplit/src/features/expenses/domain/expense_model.dart';
import 'package:equisplit/src/features/people/domain/member_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Expense.toMap', () {
    test('rounds money at two decimals and serializes embedded entries', () {
      final expense = Expense(
        id: 'expense-1',
        groupId: 'group-1',
        description: 'Dinner',
        amount: 42.455,
        category: 'Food & Drinks',
        payerId: 'member-a',
        payerName: 'Alice',
        date: DateTime.utc(2026, 3, 1),
        isSettlement: false,
        splits: const [
          ExpenseSplit(memberId: 'member-a', amount: 21.227),
          ExpenseSplit(memberId: 'member-b', amount: 21.228),
        ],
        payments: const [ExpensePayment(memberId: 'member-a', amount: 42.455)],
        memberIds: const ['member-a', 'member-b'],
        createdBy: 'uid-alice',
      );

      final map = expense.toMap();

      expect(map['description'], 'Dinner');
      expect(map['amount'], 42.46);
      expect(map['category'], 'Food & Drinks');
      expect(map['payerId'], 'member-a');
      expect(map['payerName'], 'Alice');
      expect(map['isSettlement'], isFalse);
      expect(map['createdBy'], 'uid-alice');
      expect(map['memberIds'], ['member-a', 'member-b']);
      expect(map['date'], isA<Timestamp>());
      expect(map['splits'], [
        {'memberId': 'member-a', 'amount': 21.23},
        {'memberId': 'member-b', 'amount': 21.23},
      ]);
      expect(map['payments'], [
        {'memberId': 'member-a', 'amount': 42.46},
      ]);
    });

    test('round-trips through fromMap', () {
      final expense = Expense(
        id: 'expense-1',
        groupId: 'group-1',
        description: 'Taxi',
        amount: 10,
        category: 'Transportation',
        payerId: 'member-a',
        payerName: 'Alice',
        date: DateTime.utc(2026, 3, 2),
        isSettlement: true,
        splits: const [ExpenseSplit(memberId: 'member-b', amount: 10)],
        payments: const [ExpensePayment(memberId: 'member-a', amount: 10)],
        memberIds: const ['member-a', 'member-b'],
        createdBy: 'uid-alice',
      );

      final restored = Expense.fromMap('group-1', 'expense-1', expense.toMap());

      expect(restored.id, expense.id);
      expect(restored.groupId, expense.groupId);
      expect(restored.description, expense.description);
      expect(restored.amount, expense.amount);
      expect(restored.category, expense.category);
      expect(restored.payerId, expense.payerId);
      expect(restored.payerName, expense.payerName);
      expect(restored.isSettlement, isTrue);
      expect(restored.createdBy, expense.createdBy);
      expect(restored.memberIds, expense.memberIds);
      expect(restored.splits.single.memberId, 'member-b');
      expect(restored.splits.single.amount, 10);
      expect(restored.payments.single.memberId, 'member-a');
      expect(
        restored.date.millisecondsSinceEpoch,
        expense.date.millisecondsSinceEpoch,
      );
    });
  });

  group('Member.toMap', () {
    test('writes isRemoved false and a Timestamp for new placeholders', () {
      final member = Member(id: 'member-1', name: 'Alice', groupId: 'group-1');

      final map = member.toMap();

      // Rules expect an explicit isRemoved flag on create (AGENTS.md §9.8).
      expect(map['isRemoved'], isFalse);
      expect(map['isAdmin'], isFalse);
      expect(map['hasFcmToken'], isFalse);
      expect(map['name'], 'Alice');
      expect(map['uid'], isNull);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('round-trips through fromMap', () {
      final member = Member(
        id: 'member-1',
        name: 'Alice',
        groupId: 'group-1',
        userId: 'uid-alice',
        isAdmin: true,
        isRemoved: false,
        email: 'alice@example.com',
        avatarUrl: 'https://example.com/a.png',
        hasFcmToken: true,
        createdAt: DateTime.utc(2026, 2, 3),
      );

      final restored = Member.fromMap('group-1', 'member-1', member.toMap());

      expect(restored.name, member.name);
      expect(restored.userId, member.userId);
      expect(restored.isAdmin, isTrue);
      expect(restored.isRemoved, isFalse);
      expect(restored.email, member.email);
      expect(restored.avatarUrl, member.avatarUrl);
      expect(restored.hasFcmToken, isTrue);
      expect(
        restored.createdAt!.millisecondsSinceEpoch,
        member.createdAt!.millisecondsSinceEpoch,
      );
    });
  });

  group('CashInflow.toMap', () {
    test('writes the uid field, rounded amount and a Timestamp date', () {
      final inflow = CashInflow(
        id: 'inflow-1',
        userId: 'uid-1',
        amount: 100.005,
        currencyCode: 'PKR',
        category: 'Salary',
        description: 'October salary',
        date: DateTime.utc(2026, 10, 1),
      );

      final map = inflow.toMap();

      expect(map['uid'], 'uid-1');
      expect(map['amount'], 100.01);
      expect(map['currencyCode'], 'PKR');
      expect(map['category'], 'Salary');
      expect(map['description'], 'October salary');
      expect(map['expenseId'], isNull);
      expect(map['date'], isA<Timestamp>());
    });
  });

  group('User.toMap', () {
    test('writes the client-owned profile fields', () {
      final user = User(
        id: 'uid-1',
        email: 'alice@example.com',
        name: 'Alice',
        avatarUrl: 'https://example.com/a.png',
        defaultCurrency: 'GBP',
        personalGroupId: 'group-personal',
      );

      final map = user.toMap();

      expect(map['email'], 'alice@example.com');
      expect(map['name'], 'Alice');
      expect(map['avatarUrl'], 'https://example.com/a.png');
      expect(map['defaultCurrency'], 'GBP');
      expect(map['personalGroupId'], 'group-personal');
      expect(map['premiumUntil'], isNull);
    });
  });

  group('Category.fromMap', () {
    test('reads the name and icon with safe defaults', () {
      final category = Category.fromMap('group-1', 'category-1', {
        'name': 'Food & Drinks',
        'icon': '🍔',
      });

      expect(category.id, 'category-1');
      expect(category.groupId, 'group-1');
      expect(category.name, 'Food & Drinks');
      expect(category.icon, '🍔');
    });

    test('falls back to General without an icon on sparse documents', () {
      final category = Category.fromMap('group-1', 'category-2', const {});

      expect(category.name, 'General');
      expect(category.icon, isNull);
      expect(category.groupId, 'group-1');
    });
  });
}
