import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equisplit/src/features/auth/domain/user_model.dart';
import 'package:equisplit/src/features/cash_inflows/domain/cash_inflow_model.dart';
import 'package:equisplit/src/features/expenses/domain/expense_model.dart';
import 'package:equisplit/src/features/groups/domain/group_model.dart';
import 'package:equisplit/src/features/people/domain/member_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group.fromMap', () {
    test('reads string ids, member uids and timestamps', () {
      final createdAt = DateTime.utc(2026, 2, 3);
      final group = Group.fromMap('group-1', {
        'name': 'Trip',
        'currency': 'EUR',
        'type': 'REGULAR',
        'ownerUid': 'uid-owner',
        'memberUids': ['uid-owner', 'uid-friend'],
        'createdAt': Timestamp.fromDate(createdAt),
      });

      expect(group.id, 'group-1');
      expect(group.name, 'Trip');
      expect(group.currency, 'EUR');
      expect(group.ownerUid, 'uid-owner');
      expect(group.memberUids, ['uid-owner', 'uid-friend']);
      expect(
        group.createdAt.millisecondsSinceEpoch,
        createdAt.millisecondsSinceEpoch,
      );
      expect(group.isPersonal, isFalse);
    });
  });

  group('Member.fromMap', () {
    test('maps admin/removed flags and linked uid', () {
      final member = Member.fromMap('group-1', 'member-1', {
        'name': 'Alice',
        'uid': 'uid-alice',
        'isAdmin': true,
        'isRemoved': false,
        'hasFcmToken': true,
      });

      expect(member.id, 'member-1');
      expect(member.groupId, 'group-1');
      expect(member.userId, 'uid-alice');
      expect(member.isAdmin, isTrue);
      expect(member.isRemoved, isFalse);
      expect(member.hasFcmToken, isTrue);
    });

    test('tolerates legacy integer admin flags', () {
      final member = Member.fromMap('group-1', 'member-1', {
        'name': 'Bob',
        'isAdmin': 1,
        'isRemoved': 0,
      });

      expect(member.isAdmin, isTrue);
      expect(member.isRemoved, isFalse);
    });
  });

  group('Expense.fromMap', () {
    test('reads embedded splits/payments and derives memberIds', () {
      final expense = Expense.fromMap('group-1', 'expense-1', {
        'description': 'Dinner',
        'amount': 42.5,
        'category': 'Food & Drinks',
        'payerId': 'member-a',
        'payerName': 'Alice',
        'date': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
        'isSettlement': false,
        'splits': [
          {'memberId': 'member-a', 'amount': 21.25},
          {'memberId': 'member-b', 'amount': 21.25},
        ],
        'payments': [
          {'memberId': 'member-a', 'amount': 42.5},
        ],
        'createdBy': 'uid-alice',
      });

      expect(expense.id, 'expense-1');
      expect(expense.groupId, 'group-1');
      expect(expense.splits.length, 2);
      expect(expense.payments.single.memberId, 'member-a');
      expect(expense.memberIds.toSet(), {'member-a', 'member-b'});
      expect(expense.payerName, 'Alice');
    });

    test('prefers stored memberIds when present', () {
      final expense = Expense.fromMap('group-1', 'expense-2', {
        'description': 'Taxi',
        'amount': 10,
        'payerId': 'member-a',
        'date': Timestamp.fromDate(DateTime.utc(2026, 3, 2)),
        'splits': [
          {'memberId': 'member-a', 'amount': 10},
        ],
        'memberIds': ['member-a', 'member-z'],
        'createdBy': 'uid-alice',
      });

      expect(expense.memberIds, ['member-a', 'member-z']);
    });

    test('buildMemberIds unions payer, splits and payments', () {
      expect(
        Expense.buildMemberIds(
          payerId: 'a',
          splits: {'a': 5, 'b': 5},
          payments: {'c': 10},
        ).toSet(),
        {'a', 'b', 'c'},
      );
    });
  });

  group('User.fromMap', () {
    test('maps the profile document, including premium and personal group', () {
      final user = User.fromMap('uid-1', {
        'email': 'alice@example.com',
        'name': 'Alice',
        'defaultCurrency': 'GBP',
        'isPremium': true,
        'hasPassword': false,
        'personalGroupId': 'group-personal',
      });

      expect(user.id, 'uid-1');
      expect(user.email, 'alice@example.com');
      expect(user.defaultCurrency, 'GBP');
      expect(user.isPremium, isTrue);
      expect(user.hasPassword, isFalse);
      expect(user.personalGroupId, 'group-personal');
    });

    test('falls back to the email local part when name is missing', () {
      final user = User.fromMap('uid-1', {'email': 'bob@example.com'});

      expect(user.name, 'bob');
      expect(user.defaultCurrency, 'USD');
      expect(user.hasPassword, isTrue);
    });
  });

  group('CashInflow.fromMap', () {
    test('reads the uid field and date', () {
      final date = DateTime.utc(2026, 4, 1);
      final inflow = CashInflow.fromMap('inflow-1', {
        'uid': 'uid-1',
        'amount': 100,
        'currencyCode': 'USD',
        'category': 'Salary',
        'description': 'April salary',
        'date': Timestamp.fromDate(date),
        'expenseId': null,
      });

      expect(inflow.userId, 'uid-1');
      expect(inflow.amount, 100);
      expect(inflow.date.millisecondsSinceEpoch, date.millisecondsSinceEpoch);
      expect(inflow.expenseId, isNull);
    });
  });
}
