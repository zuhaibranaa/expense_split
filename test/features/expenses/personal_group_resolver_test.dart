import 'package:equisplit/src/features/auth/domain/user_model.dart';
import 'package:equisplit/src/features/expenses/presentation/expenses_providers.dart';
import 'package:equisplit/src/features/groups/domain/group_model.dart';
import 'package:flutter_test/flutter_test.dart';

Group _group(String id, {String type = 'REGULAR', String ownerUid = 'uid-1'}) {
  return Group(
    id: id,
    name: 'Group $id',
    currency: 'USD',
    createdAt: DateTime.utc(2026, 1, 1),
    type: type,
    ownerUid: ownerUid,
  );
}

User _user({String? personalGroupId}) {
  return User(
    id: 'uid-1',
    email: 'alice@example.com',
    name: 'Alice',
    personalGroupId: personalGroupId,
  );
}

void main() {
  group('resolvePersonalGroup', () {
    test('returns null while auth or the group list is unavailable', () {
      expect(resolvePersonalGroup(null, [_group('g1')]), isNull);
      expect(resolvePersonalGroup(_user(), null), isNull);
      expect(resolvePersonalGroup(null, null), isNull);
    });

    test('prefers the personalGroupId pointer', () {
      final user = _user(personalGroupId: 'g1');
      final groups = [_group('g1'), _group('g2', type: 'PERSONAL')];

      expect(resolvePersonalGroup(user, groups)?.id, 'g1');
    });

    test(
      'falls back to the owned PERSONAL group when the pointer is unset',
      () {
        final user = _user();
        final groups = [
          _group('g1'),
          _group('g2', type: 'PERSONAL'),
          _group('g3', type: 'PERSONAL', ownerUid: 'uid-2'),
        ];

        expect(resolvePersonalGroup(user, groups)?.id, 'g2');
      },
    );

    test('falls back when the pointer dangles', () {
      final user = _user(personalGroupId: 'deleted-group');
      final groups = [_group('g1'), _group('g2', type: 'PERSONAL')];

      expect(resolvePersonalGroup(user, groups)?.id, 'g2');
    });

    test('returns null when there is no personal group at all', () {
      final user = _user();
      final groups = [_group('g1'), _group('g2')];

      expect(resolvePersonalGroup(user, groups), isNull);
    });

    test('ignores personal groups owned by someone else', () {
      final user = _user();
      final groups = [_group('g2', type: 'PERSONAL', ownerUid: 'uid-2')];

      expect(resolvePersonalGroup(user, groups), isNull);
    });

    test('treats an empty pointer as unset', () {
      final user = _user(personalGroupId: '');
      final groups = [_group('g2', type: 'PERSONAL')];

      expect(resolvePersonalGroup(user, groups)?.id, 'g2');
    });
  });
}
