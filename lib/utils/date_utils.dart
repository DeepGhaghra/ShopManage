import 'package:intl/intl.dart';

extension DateTimeIST on DateTime {
  /// Converts the DateTime to IST (UTC+5:30)
  DateTime toIST() {
    // Standard IST is UTC + 5 hours 30 minutes
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
    // The original DateTime might be local or UTC.
    // We want the start of the day *in IST*.
    // First, convert this DateTime to its IST representation.
    final istDateTime = toIST();
    // Then, create a new DateTime representing the start of that IST day.
    // This new DateTime will be in the local timezone by default if not specified,
    // but its year, month, day components will correspond to the IST date.
    // To ensure consistency, we can make it a UTC DateTime if the original was UTC,
    // or just ensure it's treated as a "local" date in terms of its components.
    // For simplicity and consistency with how DateTime works,
    // creating it without specifying isUtc will make it a local DateTime.
    // If we want it to be a UTC DateTime representing the start of the IST day,
    // we would need to calculate its UTC equivalent.
    // However, the purpose of startOfDayIST is to get the date components in IST.
    return DateTime(istDateTime.year, istDateTime.month, istDateTime.day);
  }

  /// Returns the start of the day in IST as a UTC string for database queries
  String startOfDayISTInUTCString() {
    final start = startOfDayIST();
    // Start of day in IST is 5h 30m ahead of UTC
    // So if IST is 2024-01-01 00:00:00, UTC is 2023-12-31 18:30:00
    return start
        .subtract(const Duration(hours: 5, minutes: 30))
        .toIso8601String();
  }
}
