import 'dart:io';

import 'package:equisplit/src/core/constants/default_categories.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards AGENTS.md §9 pitfall 12: the seed list is duplicated in
/// `lib/src/core/constants/default_categories.dart` and
/// `functions/src/lib/constants.ts` and must be changed together.
void main() {
  group('kDefaultCategories', () {
    test('has nine uniquely named categories with icons', () {
      expect(kDefaultCategories, hasLength(9));
      expect(
        kDefaultCategories.map((category) => category.name).toSet(),
        hasLength(9),
      );
      expect(
        kDefaultCategories.every((category) => category.icon.isNotEmpty),
        isTrue,
      );
    });

    test('stays in sync with functions/src/lib/constants.ts', () {
      final file = File('functions/src/lib/constants.ts');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'functions/src/lib/constants.ts not found — run flutter test '
            'from the expense_split package root',
      );

      final entries = RegExp(
        r"id:\s*'([^']+)'\s*,\s*name:\s*'([^']+)'\s*,\s*icon:\s*'([^']+)'",
      ).allMatches(file.readAsStringSync()).toList();

      expect(entries, isNotEmpty, reason: 'could not parse DEFAULT_CATEGORIES');

      expect(
        entries.map((entry) => entry.group(2)),
        kDefaultCategories.map((category) => category.name),
        reason: 'category names differ between Dart and Functions constants',
      );
      expect(
        entries.map((entry) => entry.group(3)),
        kDefaultCategories.map((category) => category.icon),
        reason: 'category icons differ between Dart and Functions constants',
      );
    });
  });
}
