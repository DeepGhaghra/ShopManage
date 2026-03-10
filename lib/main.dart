import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'routing/router.dart';
import 'theme/app_theme.dart';
import 'services/connectivity_providers.dart';
import 'services/log_service.dart';
import 'services/log_repository.dart';
import 'services/auth_listener.dart';
import 'ui/common/offline_checklist_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");
  
  // 1. Initialize Supabase first (needed for remote logging)
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  // 2. Setup Log Service with Remote Repository
  final logRepo = LogRepository(Supabase.instance.client);
  final logService = LogService(logRepo);
  await logService.init();
  logService.info('System', 'App boot started with remote logging');

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
