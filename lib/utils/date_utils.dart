import 'package:intl/intl.dart';

extension DateTimeIST on DateTime {
  /// Converts the DateTime to IST (UTC+5:30)
  DateTime toIST() {
    return toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  /// Formats the DateTime as IST with standard format: dd MMM yyyy, hh:mm a
  String formatIST([String pattern = 'dd MMM yyyy, hh:mm a']) {
    return DateFormat(pattern).format(toIST());
  }

  /// Formats the DateTime as IST with time only: hh:mm a
  String formatTimeIST() {
    return DateFormat('hh:mm a').format(toIST());
  }

  /// Formats the DateTime as IST with date only: dd MMM yyyy
  String formatDateIST() {
    return DateFormat('dd MMM yyyy').format(toIST());
  }

  /// Returns the start of the day in IST for this DateTime
  DateTime startOfDayIST() {
    final ist = toIST();
    return DateTime(ist.year, ist.month, ist.day);
  }

  /// Returns the start of the day in IST as a UTC string for database queries
  String startOfDayISTInUTCString() {
    final start = startOfDayIST();
    // Start of day in IST is 5h 30m ahead of UTC
    // So if IST is 2024-01-01 00:00:00, UTC is 2023-12-31 18:30:00
    return start.subtract(const Duration(hours: 5, minutes: 30)).toIso8601String();
  }
}
