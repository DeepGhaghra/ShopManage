import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/core_providers.dart';
import '../../theme/app_theme.dart';
import '../common/confirmation_dialog.dart';
import '../common/app_version_display.dart';

class AppDrawer extends ConsumerWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await ConfirmationDialog.showSignOut(context);
    if (confirmed != true) return;

    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('👋 Signed out successfully. See you soon!'),
          backgroundColor: Colors.blueGrey.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeShop = ref.watch(activeShopProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDim],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.account_balance, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(
                  activeShop?.shopName ?? 'ShopManage',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          _drawerItem(
            context,
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: '/',
            isSelected: currentRoute == '/',
          ),
          _drawerItem(
            context,
            icon: Icons.shopping_cart_outlined,
            label: 'Sales Entry',
            route: '/sales',
            isSelected: currentRoute == '/sales',
          ),
          _drawerItem(
            context,
            icon: Icons.add_shopping_cart_outlined,
            label: 'Purchase Entry',
            route: '/purchase',
            isSelected: currentRoute == '/purchase',
          ),
          _drawerItem(
            context,
            icon: Icons.inventory_2_outlined,
            label: 'Stock View',
            route: '/stock',
            isSelected: currentRoute == '/stock',
          ),
          _drawerItem(
            context,
            icon: Icons.people_outline,
            label: 'Parties List',
            route: '/parties',
            isSelected: currentRoute == '/parties',
          ),
          _drawerItem(
            context,
            icon: Icons.request_quote_outlined,
            label: 'Price List',
            route: '/pricelist',
            isSelected: currentRoute == '/pricelist',
          ),
          const Divider(),
          _drawerItem(
            context,
            icon: Icons.bug_report_outlined,
            label: 'Activity Log',
            route: '/logs',
            isSelected: currentRoute == '/logs',
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _signOut(context);
            },
          ),
          const AppVersionDisplay(),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      onTap: () {
        Navigator.pop(context);
        if (isSelected) return;
        if (route == '/') {
          context.go(route);
        } else {
          context.push(route);
        }
      },
    );
  }
}
