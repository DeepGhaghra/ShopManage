import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/core_providers.dart';
import '../common/confirmation_dialog.dart';
import '../common/app_version_display.dart';
import 'package:shopmanage/theme/app_theme.dart';

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
    final isAdmin = ref.watch(isAdminProvider);
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  activeShop?.shopName ?? 'ShopManage',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin ? 'ADMINISTRATOR' : 'STAFF USER',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (isAdmin) ...[
                  _drawerItem(
                    context,
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Admin Dashboard',
                    route: '/admin',
                    isSelected: currentRoute == '/admin',
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.folder_open_outlined,
                    label: 'Manage Folders',
                    route: '/admin/folders',
                    isSelected: currentRoute == '/admin/folders',
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: 'Manage Products',
                    route: '/admin/products',
                    isSelected: currentRoute == '/admin/products',
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.location_on_outlined,
                    label: 'Manage Locations',
                    route: '/admin/locations',
                    isSelected: currentRoute == '/admin/locations',
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 24),
                ],
                // Only show user pages if NOT in admin mode AND user is NOT an admin
                if (!isAdmin && !currentRoute.startsWith('/admin')) ...[
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
                  const Divider(indent: 16, endIndent: 16, height: 24),
                ],
                _drawerItem(
                  context,
                  icon: Icons.history_rounded,
                  label: 'Activity Log',
                  route: '/logs',
                  isSelected: currentRoute == '/logs',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _drawerItem(
            context,
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            route: '',
            color: Colors.redAccent,
            onTapOverride: () {
              Navigator.pop(context);
              _signOut(context);
            },
          ),
          const SizedBox(height: 12),
          const AppVersionDisplay(),
          const SizedBox(height: 12),
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
    Color? color,
    VoidCallback? onTapOverride,
  }) {
    final effectiveColor = color ?? (isSelected ? AppColors.primary : AppColors.textSecondary);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Icon(
          icon, 
          color: effectiveColor,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
        onTap: onTapOverride ?? () {
          Navigator.pop(context);
          if (isSelected) return;
          if (route == '/') {
            context.go(route);
          } else {
            context.push(route);
          }
        },
      ),
    );
  }
}
