import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopmanage/theme/app_theme.dart';
import '../../services/core_providers.dart';
import '../../models/shop.dart';

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
                final selectedShop = selectedShopId == null 
                    ? null 
                    : shops.firstWhere((s) => s.id == selectedShopId, orElse: () => shops.first);
                
                final screenWidth = MediaQuery.of(context).size.width;
                final dropDownWidth = screenWidth < 380 ? 100.0 : (isMobile ? 120.0 : 250.0);
                
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: dropDownWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedShop != null && !isMobile)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            selectedShop.shopShortName ?? selectedShop.shopName.substring(0, 3).toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                          ),
                        ),
                      Flexible(
                        child: Theme(
                          data: Theme.of(context).copyWith(canvasColor: AppColors.primary),
                          child: DropdownButton<int?>(
                            value: selectedShopId,
                            underline: const SizedBox(),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
                            dropdownColor: AppColors.primary,
                            items: [
                              DropdownMenuItem(
                                value: null, 
                                child: Text(
                                  screenWidth < 380 ? 'Shops' : 'All Shops', 
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...shops.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.shopName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              )),
                            ],
                            onChanged: onShopChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          if (actions != null) ...actions!,
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

