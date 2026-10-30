import 'package:equisplit/src/core/firebase/firestore_converters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('number converters', () {
    test('asDouble accepts numbers and numeric strings', () {
      expect(asDouble(12), 12.0);
      expect(asDouble('12.5'), 12.5);
      expect(asDouble(null, 3), 3.0);
      expect(asDouble('nope', 7), 7.0);
    });

    test('roundMoney rounds half away from zero at 2 decimals', () {
      expect(roundMoney(1.234), 1.23);
      expect(roundMoney(1.235), 1.24);
      expect(roundMoney(10.0 / 3), 3.33);
    });

    test('asInt tolerates strings', () {
      expect(asInt('42'), 42);
      expect(asInt(4.9), 4);
      expect(asInt('x', 1), 1);
    });
  });

  group('boolean converters', () {
    test('asBool handles bool, num and string', () {
      expect(asBool(true), isTrue);
      expect(asBool(1), isTrue);
      expect(asBool(0), isFalse);
      expect(asBool('true'), isTrue);
      expect(asBool('false'), isFalse);
      expect(asBool(null, true), isTrue);
    });
  });

  group('timestamp converters', () {
    test('timestampToDate reads Timestamps, DateTimes and ISO strings', () {
      final date = DateTime.utc(2026, 5, 4, 12);
      expect(
        timestampToDate(Timestamp.fromDate(date))?.millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      );
      expect(
        timestampToDate(date)?.millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      );
      expect(
        timestampToDate(date.toIso8601String())?.millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      );
      expect(timestampToDate(null), isNull);
    });

    test('dateToTimestamp round-trips', () {
      final date = DateTime.utc(2026, 1, 2, 3, 4);
      expect(
        dateToTimestamp(date)?.toDate().millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      );
      expect(dateToTimestamp(null), isNull);
    });
  });

  group('collection converters', () {
    test('asStringList drops empty and null entries', () {
      expect(asStringList(['a', null, '', 'b']), ['a', 'b']);
      expect(asStringList(null), isEmpty);
    });

    test('asEntryList keeps maps and normalises keys', () {
      final entries = asEntryList([
        {'memberId': 'a', 'amount': 2},
        'invalid',
        {1: 'x'},
      ]);

      expect(entries.length, 2);
      expect(entries.first['memberId'], 'a');
      expect(entries.last['1'], 'x');
    });

    test('asStringOrNull treats empty strings as null', () {
      expect(asStringOrNull(''), isNull);
      expect(asStringOrNull('value'), 'value');
    });
  });
}
