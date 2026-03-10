import 'package:intl/intl.dart';

enum LogLevel { info, success, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String module;   // e.g. 'Sales', 'Stock', 'Auth', 'Purchase'
  final String message;
  final String? details; // optional stack trace or extra info
  final int? id;         // From Supabase
  final String? userEmail; // From Supabase

  LogEntry({
    required this.level,
    required this.module,
    required this.message,
    this.details,
    this.id,
    this.userEmail,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'module': module,
    'message': message,
    if (details != null) 'details': details,
    if (id != null) 'id': id,
    if (userEmail != null) 'user_email': userEmail,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      level: LogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      module: (json['module'] as String?) ?? 'Unknown',
      message: (json['message'] as String?) ?? '',
      details: json['details']?.toString(),
      id: json['id'] as int?,
      userEmail: json['user_email'] as String?,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
    );
  }

  LogEntry withIdAndTimestamp(int id, DateTime ts, String? email) {
    return LogEntry(
      level: level,
      module: module,
      message: message,
      details: details,
      id: id,
      userEmail: email,
      timestamp: ts,
    );
  }

  String get formattedTime => DateFormat('HH:mm:ss').format(timestamp);
  String get formattedDate => DateFormat('dd MMM yyyy').format(timestamp);
  String get fullFormatted => DateFormat('dd MMM yyyy • HH:mm:ss').format(timestamp);

  @override
  String toString() => '[$fullFormatted] [${level.name.toUpperCase()}] [$module] $message${details != null ? '\n  → $details' : ''}';
}
