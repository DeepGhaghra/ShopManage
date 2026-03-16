import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'log_repository.dart';
import '../models/log_entry.dart';
import 'core_providers.dart';
import '../utils/date_utils.dart';

export '../models/log_entry.dart';

// ─── Log Service ────────────────────────────────────────────────────────────
class LogService {
  static const int _maxInMemoryLogs = 500;
  final List<LogEntry> _logs = [];
  File? _logFile;
  LogRepository? _remoteRepo;
  bool _initialized = false;
  int _version = 0; // Incremented on every log to allow UI reactivity

  LogService([this._remoteRepo]);

  /// The current version stamp. UI can poll or watch this to know logs changed.
  int get version => _version;

  bool get _shouldPrint => kDebugMode && dotenv.env['APP_DEBUG'] == 'true';

  UnmodifiableListView<LogEntry> get logs => UnmodifiableListView(_logs);

  int get totalCount => _logs.length;
  int get errorCount => _logs.where((l) => l.level == LogLevel.error).length;
  int get warningCount => _logs.where((l) => l.level == LogLevel.warning).length;
  int get successCount => _logs.where((l) => l.level == LogLevel.success).length;

  /// Fetch remote logs from Supabase
  Future<void> syncRemoteLogs() async {
    try {
      if (_remoteRepo == null) return;
      
      final remoteLogs = await _remoteRepo!.fetchRemoteLogs();
      _logs.clear();
      if (remoteLogs.isNotEmpty) {
        _logs.addAll(remoteLogs);
      }
      _version++;
    } catch (e) {
      _log(LogLevel.error, 'System', 'Remote sync failed', e.toString());
      rethrow;
    }
  }

  /// Initialize file-based logging (skipped on web)
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final logDir = Directory(p.join(dir.path, 'ShopManage', 'logs'));
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        final today = DateTime.now().toIST().formatDateIST().replaceAll('/', '-'); // Use IST for file name
        _logFile = File(p.join(logDir.path, 'app_log_$today.txt'));
        
        // Load existing logs from today's file
        if (await _logFile!.exists()) {
          final lines = await _logFile!.readAsLines();
          // Only load last 200 lines to keep memory low
          final start = lines.length > 200 ? lines.length - 200 : 0;
          for (int i = start; i < lines.length; i++) {
            try {
              final decoded = jsonDecode(lines[i]);
              if (decoded is Map<String, dynamic>) {
                _logs.add(LogEntry.fromJson(decoded));
              }
            } catch (_) {
              // Ignore corrupted lines
            }
          }
        }
        
        _log(LogLevel.info, 'System', 'Log service initialized. File: ${_logFile!.path}');
      } catch (e) {
        if (_shouldPrint) debugPrint('LogService init error: $e');
        _log(LogLevel.warning, 'System', 'File logging unavailable, using in-memory only', e.toString());
      }
    } else {
      _log(LogLevel.info, 'System', 'Log service initialized (Web - in-memory only)');
    }
    
    // Auto-sync initial logs if remote repo is there
    syncRemoteLogs();
  }

  // ── Core log method ──────────────────────────────────────────────────────
  void _log(LogLevel level, String module, String message, [String? details]) {
    final entry = LogEntry(level: level, module: module, message: message, details: details);
    
    // Add to in-memory (and stay consistent if we sync later)
    if (_logs.length >= _maxInMemoryLogs) {
      _logs.removeAt(_logs.length - 1); // Remove oldest
    }
    _logs.insert(0, entry); // Add to top for local freshness

    // Write to file (local persistence)
    if (_logFile != null && !kIsWeb) {
      _logFile!.writeAsString('${jsonEncode(entry.toJson())}\n', mode: FileMode.append).catchError((e) {
        if (_shouldPrint) debugPrint('Log write error: $e');
      });
    }

    // Remote logging to Supabase
    if (_remoteRepo != null) {
      _remoteRepo!.pushRemoteLog(entry);
    }

    // Also print in debug mode
    if (_shouldPrint) {
      debugPrint(entry.toString());
    }

    _version++;
  }

  // ── Public API ───────────────────────────────────────────────────────────
  void info(String module, String message, [String? details]) =>
      _log(LogLevel.info, module, message, details);

  void success(String module, String message, [String? details]) =>
      _log(LogLevel.success, module, message, details);

  void warning(String module, String message, [String? details]) =>
      _log(LogLevel.warning, module, message, details);

  void error(String module, String message, [dynamic error, StackTrace? stack]) =>
      _log(LogLevel.error, module, message, _formatError(error, stack));

  String _formatError(dynamic error, StackTrace? stack) {
    final buffer = StringBuffer();
    if (error != null) buffer.writeln('Error: $error');
    if (stack != null) buffer.writeln('Stack: ${stack.toString().split('\n').take(5).join('\n')}');
    return buffer.toString().trim();
  }

  // ── Filtering ────────────────────────────────────────────────────────────
  List<LogEntry> getByLevel(LogLevel level) =>
      _logs.where((l) => l.level == level).toList();

  List<LogEntry> getByModule(String module) =>
      _logs.where((l) => l.module.toLowerCase() == module.toLowerCase()).toList();

  List<LogEntry> search(String query) {
    final q = query.toLowerCase();
    return _logs.where((l) =>
        l.message.toLowerCase().contains(q) ||
        l.module.toLowerCase().contains(q) ||
        (l.details?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  // ── Export ────────────────────────────────────────────────────────────────
  String exportAsText() {
    return _logs.map((l) => l.toString()).join('\n');
  }

  // ── Clear ────────────────────────────────────────────────────────────────
  void clearLogs() {
    _logs.clear();
    _log(LogLevel.info, 'System', 'Local logs cleared by user');
    _version++;
  }

  /// Wipes both local and remote logs (Admin only)
  Future<void> wipeRemoteLogs() async {
    try {
      if (_remoteRepo == null) return;
      
      // 1. Delete remote
      await _remoteRepo!.clearRemoteLogs();
      
      // 2. Clear local
      _logs.clear();
      
      // 3. Document the wipe
      final entry = LogEntry(
        level: LogLevel.success, 
        module: 'System', 
        message: 'All logs (Local & Remote) wiped by administrator'
      );
      
      _logs.insert(0, entry);
      await _remoteRepo!.pushRemoteLog(entry);
      
      _version++;
    } catch (e) {
      _log(LogLevel.error, 'System', 'Failed to wipe remote logs', e.toString());
      rethrow;
    }
  }

  /// Get all log files (for multi-day browsing)
  Future<List<File>> getLogFiles() async {
    if (kIsWeb || _logFile == null) return [];
    try {
      final dir = _logFile!.parent;
      final files = await dir.list().where((e) => e is File && e.path.endsWith('.txt')).cast<File>().toList();
      files.sort((a, b) => b.path.compareTo(a.path)); // newest first
      return files;
    } catch (_) {
      return [];
    }
  }
}

// ─── Providers ──────────────────────────────────────────────────────────────
final logRepositoryProvider = Provider<LogRepository>((ref) {
  return LogRepository(ref.watch(supabaseClientProvider));
});

final logServiceProvider = Provider<LogService>((ref) {
  // Use a specialized factory to ensure it's a singleton and repo is injected
  return LogService(ref.watch(logRepositoryProvider));
});
