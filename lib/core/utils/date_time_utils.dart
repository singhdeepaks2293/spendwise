import 'package:intl/intl.dart';

/// Date helpers shared by analytics, filtering and the parser.
///
/// The app stores instants in UTC and renders them in the device's local zone.
/// Calendar arithmetic (months, day buckets) is performed on local dates so a
/// transaction at 00:30 IST belongs to the correct local day.
abstract final class DateTimeUtils {
  static DateTime startOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime endOfDay(DateTime value) {
    final start = startOfDay(value);
    return start.add(const Duration(days: 1));
  }

  static DateTime firstDayOfMonth(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month);
  }

  static DateTime lastDayOfMonth(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month + 1, 0, 23, 59, 59, 999);
  }

  static DateTime addMonths(DateTime value, int months) {
    final local = value.toLocal();
    // Dart normalises overflowing month values (e.g. month 13 -> January).
    return DateTime(local.year, local.month + months, 1);
  }

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool isSameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// Inclusive day range used by the transaction filter.
  static bool isWithinDays(DateTime value, DateTime start, DateTime end) {
    final v = value.toLocal();
    final s = startOfDay(start);
    final e = endOfDay(end);
    return !v.isBefore(s) && v.isBefore(e);
  }

  static String monthLabel(DateTime value) =>
      DateFormat('MMMM yyyy').format(value.toLocal());

  static String shortMonthLabel(DateTime value) =>
      DateFormat('MMM').format(value.toLocal());

  static String dayLabel(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    if (isSameDay(local, now)) return 'Today';
    if (isSameDay(local, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('EEE, d MMM').format(local);
  }

  static String timeLabel(DateTime value) =>
      DateFormat('h:mm a').format(value.toLocal());

  static String dateTimeLabel(DateTime value) =>
      DateFormat('d MMM yyyy, h:mm a').format(value.toLocal());

  static String isoDate(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(value.toLocal());

  /// Number of whole months between two dates, ignoring the day of month.
  static int monthsBetween(DateTime from, DateTime to) {
    final a = firstDayOfMonth(from);
    final b = firstDayOfMonth(to);
    return (b.year - a.year) * 12 + (b.month - a.month);
  }
}
