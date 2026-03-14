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
        final entry = LogEntry(
          level: LogLevel.values.firstWhere(
            (e) => e.name == json['level'],
            orElse: () => LogLevel.info,
          ),
          module: json['module'] ?? 'Unknown',
          message: json['message'] ?? '',
          details: json['details'],
        );
        // Overwrite timestamp with the one from DB
        return entry.withIdAndTimestamp(
          json['id'],
          DateTime.parse(json['timestamp']),
          json['user_email'],
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
