import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/auth/login_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/sales/sales_screen.dart';
import '../ui/stock/stock_screen.dart';
import '../ui/parties/parties_screen.dart';
import '../ui/purchase/purchase_screen.dart';
import '../ui/pricelist/pricelist_screen.dart';
import '../ui/common/log_viewer_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggingIn = state.uri.toString() == '/login';

      if (session == null && !isLoggingIn) {
        return '/login';
      }

      if (session != null && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/sales',
        builder: (context, state) => const SalesScreen(),
      ),
      GoRoute(
        path: '/stock',
        builder: (context, state) => const StockScreen(),
      ),
      GoRoute(
        path: '/parties',
        builder: (context, state) => const PartiesScreen(),
      ),
      GoRoute(
        path: '/purchase',
        builder: (context, state) => const PurchaseScreen(),
      ),
      GoRoute(
        path: '/pricelist',
        builder: (context, state) => const PricelistScreen(),
      ),
      GoRoute(
        path: '/logs',
        builder: (context, state) => const LogViewerScreen(),
      ),
    ],
  );
});
