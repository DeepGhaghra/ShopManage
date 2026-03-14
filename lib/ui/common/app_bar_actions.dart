import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/core_providers.dart';
import '../../theme/app_theme.dart';
import 'confirmation_dialog.dart';

class AppBarActions extends ConsumerWidget {
  const AppBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.storefront_rounded, color: AppColors.primary),
          tooltip: 'Switch Shop',
          onPressed: () {
            ref.read(activeShopProvider.notifier).setShop(null);
            context.go('/');
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
          tooltip: 'Sign Out',
          onPressed: () async {
            final confirmed = await ConfirmationDialog.showSignOut(context);
            if (confirmed == true) {
              await ref.read(supabaseClientProvider).auth.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('👋 Signed out successfully'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                context.go('/login');
              }
            }
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
