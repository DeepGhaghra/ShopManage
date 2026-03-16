import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';

class LogRepository {
  final SupabaseClient _client;

  LogRepository(this._client);

  Future<void> pushRemoteLog(LogEntry entry) async {
    try {
      final user = _client.auth.currentUser;
      await _client.from('activity_logs').insert({
        'timestamp': entry.timestamp.toIso8601String(),
        'level': entry.level.name,
        'module': entry.module,
        'message': entry.message,
        'details': entry.details,
        'user_email': user?.email,
      });
    } catch (e) {
      // If logging fails (RLS or network), we don't want to crash the app
      // or recurse indefinitely. Local logging will still have it.
      if (kDebugMode) {
        print('Remote logging failed: $e');
      }
    }
  }

  Future<List<LogEntry>> fetchRemoteLogs({int limit = 200}) async {
    try {
      final response = await _client
          .from('activity_logs')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);
      
      return response.map((json) {
        return LogEntry(
          id: json['id'] as int?,
          level: LogLevel.values.firstWhere(
            (e) => e.name == json['level'],
            orElse: () => LogLevel.info,
          ),
          module: json['module'] ?? 'Unknown',
          message: json['message'] ?? '',
          details: json['details'],
          userEmail: json['user_email'],
          timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : null,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> clearRemoteLogs() async {
    try {
      // Use .gt('id', -1) which matches all entries (IDs are serial positive numbers)
      await _client.from('activity_logs').delete().gt('id', -1);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear remote logs: $e');
      }
      rethrow;
    }
  }
}
