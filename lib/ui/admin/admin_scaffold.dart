import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopmanage/theme/app_theme.dart';
import '../../services/core_providers.dart';
import '../../models/shop.dart';
import '../common/searchable_selector.dart';
import '../common/confirmation_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class AdminScaffold extends ConsumerWidget {
  final String title;
  final Widget? body;
  final Widget? drawer;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final int? selectedShopId;
  final Function(int?)? onShopChanged;
  final Color? backgroundColor;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.drawer,
    this.actions,
    this.floatingActionButton,
    this.selectedShopId,
    this.onShopChanged,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(associatedShopsProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: drawer != null 
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        centerTitle: false,
        titleSpacing: 4,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.1),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (onShopChanged != null)
            shopsAsync.when(
              data: (shops) {
                final selectedShop = (selectedShopId == null || shops.isEmpty) 
                    ? null 
                    : shops.firstWhere((s) => s.id == selectedShopId, orElse: () => shops.first);
                
                final screenWidth = MediaQuery.of(context).size.width;
                final dropDownWidth = screenWidth < 380 ? 100.0 : (isMobile ? 120.0 : 250.0);
                
                final shopMap = [
                  {'id': null, 'shop_name': 'All Shops'},
                  ...shops.map((s) => {'id': s.id, 'shop_name': s.shopName}),
                ];
                
                return InkWell(
                  onTap: () => SearchableSelector.show(
                    context: context,
                    title: 'Switch Shop',
                    items: shopMap,
                    labelKey: 'shop_name',
                    icon: Icons.storefront_rounded,
                    iconColor: AppColors.primary,
                    onSelected: (id) => onShopChanged!(id), 
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_rounded, color: Colors.white.withOpacity(0.9), size: 16),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: dropDownWidth),
                          child: Text(
                            selectedShop?.shopName ?? 'All Shops',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.7), size: 16),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          if (actions != null) ...actions!,
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirmed = await ConfirmationDialog.showSignOut(context);
              if (confirmed == true) {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: drawer,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000), // Reduced from 1200
          child: body,
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

