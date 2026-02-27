import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../services/core_providers.dart';
import '../../services/dashboard_providers.dart';
import '../../services/export_service.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
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

    // If no shop is selected, show the Shop Selection screen overlay or embedded
    if (activeShop == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select a Shop'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(context),
              tooltip: 'Sign Out',
            ),
          ],
        ),
        body: const _ShopSelectionView(),
      );
    }

    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeShop.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: () {
              ref.read(activeShopProvider.notifier).setShop(null); // Clear shop to re-select
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('🔄 Switched to shop selection'),
                  backgroundColor: AppColors.primaryDim,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Switch Shop',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      drawer: Drawer(
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
                    activeShop.shopName,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: const Text('Sales Entry'),
              onTap: () {
                Navigator.pop(context);
                context.push('/sales');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart_outlined),
              title: const Text('Purchase Entry'),
              onTap: () {
                Navigator.pop(context);
                context.push('/purchase');
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Stock View'),
              onTap: () {
                Navigator.pop(context);
                context.push('/stock');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Parties'),
              onTap: () {
                Navigator.pop(context);
                context.push('/parties');
              },
            ),
          ],
        ),
      ),
      body: metricsAsync.when(
        data: (metrics) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dashboard',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateTime.now().toString().split(' ')[0], // Simple date display
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _MetricCard(
                      title: 'Today Sales Qty',
                      value: '${metrics['todaySalesQty'] ?? 0}',
                      icon: Icons.analytics_rounded,
                      color: const Color(0xFF1976D2),
                      onTap: () => _showTodaySalesDetail(context, activeShop.id),
                    ),
                    const SizedBox(width: 16),
                    _MetricCard(
                      title: 'Low Stock (Qty < 3)',
                      value: '${metrics['lowStockCount'] ?? 0}',
                      icon: Icons.notification_important_rounded,
                      color: const Color(0xFFD32F2F),
                      onTap: () => _showLowStockDetail(context, activeShop.id),
                    ),
                    const SizedBox(width: 16),
                    _MetricCard(
                      title: 'Trending Qty (30d)',
                      value: '${metrics['trendingMaxQty'] ?? 0}',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF388E3C),
                      onTap: () => _showTrendingDetail(context, activeShop.id),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  'Quick Operations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount;
                    double childAspectRatio;
                    
                    if (constraints.maxWidth >= 1400) {
                      crossAxisCount = 6;
                      childAspectRatio = 1.1;
                    } else if (constraints.maxWidth >= 1100) {
                      crossAxisCount = 5;
                      childAspectRatio = 1.1;
                    } else if (constraints.maxWidth >= 800) {
                      crossAxisCount = 4;
                      childAspectRatio = 1.05;
                    } else if (constraints.maxWidth >= 600) {
                      crossAxisCount = 3;
                      childAspectRatio = 1.05;
                    } else {
                      crossAxisCount = 2;
                      childAspectRatio = 1.1; 
                    }

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: childAspectRatio,
                      children: [_ActionCard(
                          label: 'Stock View',
                          icon: Icons.inventory_2_rounded,
                          baseColor: const Color(0xFFEF6C00),
                          onTap: () => context.push('/stock'),
                        ),
                        _ActionCard(
                          label: 'New Sales',
                          icon: Icons.point_of_sale_rounded,
                          baseColor: const Color(0xFF0F4C81),
                          onTap: () => context.push('/sales'),
                        ),
                        _ActionCard(
                          label: 'New Purchase',
                          icon: Icons.add_shopping_cart_rounded,
                          baseColor: const Color(0xFF2E7D32),
                          onTap: () => context.push('/purchase'),
                        ),
                        
                      
                        _ActionCard(
                          label: 'Price List',
                          icon: Icons.request_quote_rounded,
                          baseColor: const Color(0xFFD32F2F),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('📄 Price List module coming soon!'),
                                backgroundColor: Colors.orange.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                        ),
                        _ActionCard(
                          label: 'Manage Parties',
                          icon: Icons.group_add_rounded,
                          baseColor: const Color(0xFF00838F),
                          onTap: () => context.push('/parties'),
                        ),  _ActionCard(
                          label: 'Export Data',
                          icon: Icons.import_export_rounded,
                          baseColor: const Color(0xFF6A1B9A),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (context) => _ExportBottomSheet(shopId: activeShop.id, shopName: activeShop.shopName),
                            );
                          },
                        )
                      ],
                    );
                  }
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showTodaySalesDetail(BuildContext context, int shopId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailViewSheet(
        title: "Today's Sales Records",
        shopId: shopId,
        type: 'today_sales',
      ),
    );
  }

  void _showLowStockDetail(BuildContext context, int shopId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailViewSheet(
        title: "Low Stock Items (< 3)",
        shopId: shopId,
        type: 'low_stock',
      ),
    );
  }

  void _showTrendingDetail(BuildContext context, int shopId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailViewSheet(
        title: "Trending Designs (30 Days)",
        shopId: shopId,
        type: 'trending',
      ),
    );
  }
}

class _ExportBottomSheet extends ConsumerWidget {
  final int shopId;
  final String shopName;

  const _ExportBottomSheet({required this.shopId, required this.shopName});

  Widget _buildExportRow(BuildContext context, WidgetRef ref, String title, Future<void> Function() onExcel, Future<void> Function() onPdf) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.table_chart, color: Colors.green),
            label: const Text('Excel'),
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generating $title Excel...')));
              try {
                await onExcel();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            label: const Text('PDF'),
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generating $title PDF...')));
              try {
                await onPdf();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportService = ref.read(exportServiceProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
           const Padding(
             padding: EdgeInsets.all(16.0),
             child: Text('Generate Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
           ),
           _buildExportRow(
             context, ref, 'Sales Report', 
             () => exportService.exportSalesToExcel(shopId, shopName), 
             () => exportService.exportSalesToPdf(shopId, shopName)
           ),
           const Divider(),
           _buildExportRow(
             context, ref, 'Purchase Report', 
             () => exportService.exportPurchaseToExcel(shopId, shopName), 
             () => exportService.exportPurchaseToPdf(shopId, shopName)
           ),
           const Divider(),
           _buildExportRow(
             context, ref, 'Stock Report', 
             () => exportService.exportStockToExcel(shopId, shopName), 
             () => exportService.exportStockToPdf(shopId, shopName)
           ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 20),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color baseColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.baseColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.18),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: baseColor.withOpacity(0.1),
            highlightColor: baseColor.withOpacity(0.05),
            child: Stack(
              children: [
                // Decorative abstract circle top right
                Positioned(
                  top: -24,
                  right: -24,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor.withOpacity(0.04),
                    ),
                  ),
                ),
                // Faded watermark icon bottom right
                Positioned(
                  bottom: -16,
                  right: -16,
                  child: Transform.rotate(
                    angle: -0.2, // slight tilt for energy
                    child: Icon(
                      icon,
                      size: 100,
                      color: baseColor.withOpacity(0.06),
                    ),
                  ),
                ),
                // Left-edge accent border
                Positioned(
                  left: 0,
                  top: 24,
                  bottom: 24,
                  child: Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
                // Main Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Squircle icon container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              baseColor.withOpacity(0.2),
                              baseColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: baseColor, size: 30),
                      ),
                      const Spacer(),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.2,
                          color: Colors.blueGrey.shade900,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailViewSheet extends ConsumerWidget {
  final String title;
  final int shopId;
  final String type;

  const _DetailViewSheet({
    required this.title,
    required this.shopId,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchData(client),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final data = snapshot.data ?? [];
                    if (data.isEmpty) {
                      return const Center(child: Text('No records found.'));
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: data.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = data[index];
                        return _buildListItem(item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchData(SupabaseClient client) async {
    switch (type) {
      case 'today_sales':
        final today = DateTime.now().copyWith(hour: 0, minute: 0, second: 0).toUtc().toIso8601String();
        // Correct join syntax for Supabase-flutter
        final res = await client
            .from('sales_entries')
            .select('quantity, created_at, parties!inner(partyname), products_design!inner(design_no)')
            .eq('shop_id', shopId)
            .gte('created_at', today);
        return List<Map<String, dynamic>>.from(res);
      
      case 'low_stock':
        final res = await client
            .from('stock')
            .select('quantity, locations!inner(name), products_design!inner(design_no)')
            .eq('shop_id', shopId)
            .lt('quantity', 3);
        return List<Map<String, dynamic>>.from(res);

      case 'trending':
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toUtc().toIso8601String();
        final res = await client
            .from('sales_entries')
            .select('quantity, products_design!inner(design_no)')
            .eq('shop_id', shopId)
            .gte('created_at', thirtyDaysAgo);
        
        final stats = <String, int>{};
        for (final item in res) {
          final designNo = (item['products_design'] as Map)['design_no'] as String;
          final qty = item['quantity'] as int;
          stats[designNo] = (stats[designNo] ?? 0) + qty;
        }
        
        final list = stats.entries.map((e) => {'design_no': e.key, 'quantity': e.value}).toList();
        list.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
        return list;
      
      default:
        return [];
    }
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    if (type == 'today_sales') {
      final designNo = (item['products_design'] as Map)['design_no'];
      final partyName = (item['parties'] as Map)['partyname'];
      final date = DateTime.parse(item['created_at']).toLocal().toString().split(' ')[1].substring(0, 5);
      return ListTile(
        title: Text('Design: $designNo', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Party: $partyName @ $date'),
        trailing: Text('${item['quantity']} Qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
      );
    } else if (type == 'low_stock') {
      final designNo = (item['products_design'] as Map)['design_no'];
      final location = (item['locations'] as Map)['name'];
      return ListTile(
        title: Text('Design: $designNo', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Location: $location'),
        trailing: Text('${item['quantity']} Qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
      );
    } else {
      // Trending
      return ListTile(
        leading: CircleAvatar(child: Text('${item['quantity']}')),
        title: Text('Design: ${item['design_no']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Top Seller'),
      );
    }
  }
}
class _ShopSelectionView extends ConsumerWidget {
  const _ShopSelectionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(shopsProvider);

    return shopsAsync.when(
      data: (shops) {
        if (shops.isEmpty) {
          return const Center(child: Text('No shops available. Please contact admin.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          itemCount: shops.length,
          itemBuilder: (context, index) {
            final shop = shops[index];
            
            // Unique icons and colors for each shop
            final List<IconData> shopIcons = [
              Icons.storefront,
              Icons.shopping_bag,
              Icons.apartment,
              Icons.warehouse,
              Icons.business_center,
            ];
            final List<Color> shopColors = [
              const Color(0xFF0F4C81),
              const Color(0xFF2E7D32),
              const Color(0xFFC62828),
              const Color(0xFFEF6C00),
              const Color(0xFF6A1B9A),
            ];
            
            final icon = shopIcons[index % shopIcons.length];
            final color = shopColors[index % shopColors.length];

            return Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16.0),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    title: Text(
                      shop.shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 18),
                    onTap: () {
                      ref.read(activeShopProvider.notifier).setShop(shop);
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
