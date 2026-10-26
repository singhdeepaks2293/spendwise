import 'package:intl/intl.dart';

/// Currency formatting used consistently across the app.
///
/// Amounts are stored as positive `double`s plus a direction flag, so callers
/// must decide whether to prefix a sign. [formatSigned] exists for cash-flow
/// rows where direction matters.
abstract final class Money {
  static const String defaultCurrency = 'INR';

  static const Map<String, String> _symbols = <String, String>{
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'د.إ',
    'SGD': 'S\$',
  };

  static String symbolFor(String currency) =>
      _symbols[currency.toUpperCase()] ?? currency.toUpperCase();

  /// `1234.5` -> `₹1,234.50` (INR groups by lakh/crore via the en_IN locale).
  static String format(
    double amount, {
    String currency = defaultCurrency,
    bool compact = false,
    bool withSymbol = true,
  }) {
    final symbol = withSymbol ? symbolFor(currency) : '';
    final locale = currency.toUpperCase() == 'INR' ? 'en_IN' : 'en_US';
    final NumberFormat formatter;
    if (compact) {
      formatter = NumberFormat.compactCurrency(
        locale: locale,
        symbol: symbol,
        decimalDigits: 1,
      );
    } else {
      // Whole amounts read better without trailing `.00`.
      final decimalDigits = amount == amount.roundToDouble() ? 0 : 2;
      formatter = NumberFormat.currency(
        locale: locale,
        symbol: symbol,
        decimalDigits: decimalDigits,
      );
    }
    return formatter.format(amount);
  }

  /// Adds a leading `+` for credits and `−` for debits.
  static String formatSigned(
    double amount, {
    required bool isCredit,
    String currency = defaultCurrency,
  }) {
    final value = format(amount.abs(), currency: currency);
    return isCredit ? '+$value' : '−$value';
  }

  /// Parses values such as `1,23,456.78`, `₹1,200` and `1.2L` (lakh).
  ///
  /// Returns `null` when the string does not contain a sane amount.
  static double? tryParse(String input) {
    var text = input.trim().toLowerCase();
    if (text.isEmpty) return null;

    var multiplier = 1.0;
    if (RegExp(r'(\d)\s*(l|lac|lakh|lakhs)\b').hasMatch(text)) {
      multiplier = 100000;
    } else if (RegExp(r'(\d)\s*(cr|crore|crores)\b').hasMatch(text)) {
      multiplier = 10000000;
    } else if (RegExp(r'(\d)\s*(k|thousand)\b').hasMatch(text)) {
      multiplier = 1000;
    }
    text = text.replaceAll(RegExp(r'[₹$€£]|rs\.?|inr|usd|eur|gbp|aed'), '');
    text = text.replaceAll(RegExp(r'[a-z]'), '');
    text = text.replaceAll(',', '').trim();
    final value = double.tryParse(text);
    if (value == null || value <= 0 || !value.isFinite) return null;
    return value * multiplier;
  }
}
