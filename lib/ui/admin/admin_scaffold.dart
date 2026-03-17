import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopmanage/theme/app_theme.dart';
import '../../services/core_providers.dart';
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
  final PreferredSizeWidget? bottom;
  final double? maxWidth;

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
    this.bottom,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(associatedShopsProvider);
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: bottom,
        toolbarHeight: 72,
        leadingWidth: drawer != null ? 100 : 56,
        leading: drawer != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BackButton(color: AppColors.textPrimary),
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: AppColors.primary),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ],
              )
            : const BackButton(color: AppColors.textPrimary),
        centerTitle: true,
        titleSpacing: 8,
        title: shopsAsync.when(
          data: (shops) {
            final currentShop = shops
                .where((s) => s.id == selectedShopId)
                .firstOrNull;
            final subtitle =
                currentShop?.shopName ??
                (isAdmin && selectedShopId == null ? 'All Shops' : '');

            return InkWell(
              onTap: onShopChanged == null
                  ? null
                  : () {
                      final shopMap = [
                        if (isAdmin) {'id': null, 'shop_name': 'All Shops'},
                        ...shops.map(
                          (s) => {'id': s.id, 'shop_name': s.shopName},
                        ),
                      ];
                      SearchableSelector.show(
                        context: context,
                        title: 'Switch Shop',
                        items: shopMap,
                        labelKey: 'shop_name',
                        icon: Icons.storefront_rounded,
                        iconColor: AppColors.primary,
                        onSelected: (id) => onShopChanged!(id),
                      );
                    },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.divider,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.primary,
                              size: 11,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                subtitle.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (onShopChanged != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          loading: () => Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          error: (_, __) => Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        actions: [
          if (actions != null) ...actions!,
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirmed = await ConfirmationDialog.showSignOut(context);
              if (confirmed == true) {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: drawer,
      body: SizedBox.expand(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? 1000,
            ),
            child: body,
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
