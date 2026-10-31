import 'package:equisplit/src/shared/utils/currency_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyUtils.getSymbol', () {
    test('resolves common currency codes', () {
      expect(CurrencyUtils.getSymbol('USD'), r'$');
      expect(CurrencyUtils.getSymbol('EUR'), '€');
      expect(CurrencyUtils.getSymbol('GBP'), '£');
    });

    test('resolves lowercase codes case-insensitively', () {
      expect(CurrencyUtils.getSymbol('usd'), r'$');
      expect(CurrencyUtils.getSymbol('eur'), '€');
    });

    test('falls back to the code for unknown currencies', () {
      expect(CurrencyUtils.getSymbol('XYZ'), 'XYZ');
      expect(CurrencyUtils.getSymbol(''), '');
    });
  });
}
