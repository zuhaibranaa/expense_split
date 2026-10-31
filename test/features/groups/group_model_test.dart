import 'package:equisplit/src/features/groups/domain/group_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group.fromMap', () {
    test('applies safe defaults for a sparse document', () {
      final group = Group.fromMap('group-1', const {});

      expect(group.id, 'group-1');
      expect(group.name, 'Group');
      expect(group.currency, 'USD');
      expect(group.type, 'REGULAR');
      expect(group.isPersonal, isFalse);
      expect(group.ownerUid, isEmpty);
      expect(group.memberUids, isEmpty);
      // timestampToDateOrNow falls back to now for a missing createdAt.
      expect(
        group.createdAt.isAfter(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });

    test('marks PERSONAL groups', () {
      final group = Group.fromMap('group-2', {'type': 'PERSONAL'});

      expect(group.isPersonal, isTrue);
    });
  });

  group('Group.copyWith', () {
    test('keeps identity fields and overrides the rest', () {
      final createdAt = DateTime.utc(2026, 2, 3);
      final group = Group(
        id: 'group-1',
        name: 'Trip',
        currency: 'EUR',
        createdAt: createdAt,
        type: 'REGULAR',
        ownerUid: 'uid-owner',
        memberUids: const ['uid-owner'],
      );

      final renamed = group.copyWith(
        name: 'Paris trip',
        updatedAt: DateTime.utc(2026, 5, 6),
        memberUids: const ['uid-owner', 'uid-friend'],
      );

      expect(renamed.id, 'group-1');
      expect(renamed.createdAt, createdAt);
      expect(renamed.currency, 'EUR');
      expect(renamed.type, 'REGULAR');
      expect(renamed.ownerUid, 'uid-owner');
      expect(renamed.name, 'Paris trip');
      expect(renamed.updatedAt, DateTime.utc(2026, 5, 6));
      expect(renamed.memberUids, ['uid-owner', 'uid-friend']);
      // The source instance is untouched.
      expect(group.name, 'Trip');
      expect(group.memberUids, ['uid-owner']);
    });
  });
}
