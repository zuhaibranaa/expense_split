import 'package:currency_picker/currency_picker.dart';

class CurrencyUtils {
  static String getSymbol(String code) {
    final currency = CurrencyService().findByCode(code);
    return currency?.symbol ?? code;
  }
}
