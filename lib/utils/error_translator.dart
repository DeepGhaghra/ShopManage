import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorTranslator {
  static String translate(dynamic error) {
    if (error is AuthException) {
      if (error.message.toLowerCase().contains('invalid login credentials')) {
        return 'Invalid email or password. Please try again.';
      }
      return 'Authentication error: ${error.message}';
    } else if (error is PostgrestException) {
      if (error.code == '23505') { // unique_violation
        return 'This record already exists. Please use a unique value.';
      } else if (error.code == '23503') { // foreign_key_violation
        return 'This action cannot be completed because it depends on another record that is missing or deleted.';
      } else if (error.code == '42501') { // insufficient_privilege
        return 'You do not have permission to perform this action.';
      }
      return 'Database error (${error.code}): ${error.message}';
    } else if (error is Exception) {
      final msg = error.toString();
      if (msg.contains('SocketException') || msg.contains('ClientException')) {
        return 'Network connection error. Please check your internet connection.';
      }
      return msg.replaceAll('Exception: ', '');
    }
    return error?.toString() ?? 'An unknown error occurred.';
  }
}
