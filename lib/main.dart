import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'routing/router.dart';
import 'theme/app_theme.dart';
import 'services/connectivity_providers.dart';
import 'services/log_service.dart';
import 'services/auth_listener.dart';
import 'ui/common/offline_checklist_screen.dart';

// Please replace these with environment variables in a real production app.
const supabaseUrl = 'https://ltplvmmjgkaxffvwowub.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0cGx2bW1qZ2theGZmdndvd3ViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwMDA3OTIsImV4cCI6MjA4NzU3Njc5Mn0.YnygSoUuv39fUKxTxc3Dzg-HUB1iB24ZBQm88KFnlnI';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize log service early
  final logService = LogService();
  await logService.init();
  logService.info('System', 'App boot started');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  logService.success('System', 'Supabase initialized successfully');

  runApp(
    ProviderScope(
      overrides: [
        logServiceProvider.overrideWithValue(logService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize Auth Listener
    ref.read(authListenerProvider).init();

    final isOffline = ref.watch(isOfflineProvider);
    final router = ref.watch(routerProvider);
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    // Common Theme Data to avoid duplication
    final themeData = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.cardBg,
      ),
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.appBarBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );

    Widget appWidget;
    if (isOffline) {
      appWidget = MaterialApp(
        title: 'Laminates Wholesaler',
        debugShowCheckedModeBanner: false,
        theme: themeData,
        home: OfflineChecklistScreen(
          onRetry: () => ref.invalidate(connectivityStreamProvider),
        ),
      );
    } else {
      appWidget = MaterialApp.router(
        title: 'Laminates Wholesaler',
        theme: themeData,
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        ),
        themeMode: ThemeMode.system,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      );
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: appWidget,
    );
  }
}
