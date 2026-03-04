import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routing/router.dart';
import 'log_service.dart';

final authListenerProvider = Provider<AuthListener>((ref) {
  return AuthListener(ref);
});

class AuthListener {
  final Ref _ref;
  StreamSubscription<AuthState>? _subscription;

  AuthListener(this._ref);

  void init() {
    _subscription?.cancel();
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      final log = _ref.read(logServiceProvider);

      log.info('Auth', 'Auth event: ${event.name}');

      if (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userDeleted || (event == AuthChangeEvent.tokenRefreshed && session == null)) {
        log.warning('Auth', 'Session expired or user signed out. Redirecting to login.');
        _ref.read(routerProvider).go('/login');
      }
      
      if (event == AuthChangeEvent.signedIn && session != null) {
        log.success('Auth', 'User session established: ${session.user.email}');
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
