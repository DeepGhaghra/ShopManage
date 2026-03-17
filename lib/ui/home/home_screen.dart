import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../services/core_providers.dart';
import '../../services/dashboard_providers.dart';
import '../../models/shop.dart';
import '../../theme/app_theme.dart';
import '../common/error_view.dart';
import '../common/confirmation_dialog.dart';
import '../common/app_bar_actions.dart';
import '../common/app_bar_title.dart';
import '../../utils/error_translator.dart';
import '../../utils/date_utils.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeShop = ref.watch(activeShopProvider);
    final isAdmin = ref.watch(isAdminProvider);

    // FIX: If the router erroneously sent an Admin here before the profile loaded,
    // redirect them to the Admin Console now that we know they are an Admin.
    if (isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            GoRouterState.of(context).uri.toString() == '/') {
          context.go('/admin');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If no shop is selected, show the Shop Selection screen overlay or embedded
    if (activeShop == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.scaffoldBg,
          elevation: 0,
          centerTitle: true,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Workspace Selection',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              onPressed: () => ref.invalidate(shopsProvider),
              tooltip: 'Refresh Shops',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => _signOut(context),
                tooltip: 'Sign Out',
              ),
            ),
          ],
        ),
        body: const _ShopSelectionView(),
      );
    }

    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 72,
        centerTitle: true,
        title: CustomAppBarTitle(
          title: 'Dashboard',
          subtitle: activeShop.shopName,
        ),
        actions: const [AppBarActions()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardMetricsProvider),
        color: AppColors.primary,
        child: metricsAsync.when(
          data: (metrics) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dashboard',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateTime.now().formatDateIST(),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) {
                          final isMobile =
                              MediaQuery.of(context).size.width < 600;
                          if (isMobile) {
                            return Column(
                              children: [
                                _MetricCard(
                                  title: 'Today Sales Qty',
                                  value: '${metrics['todaySalesQty'] ?? 0}',
                                  icon: Icons.analytics_rounded,
                                  color: const Color(0xFF1976D2),
                                  onTap: () => _showTodaySalesDetail(
                                    context,
                                    activeShop.id,
                                  ),
                                  isExpanded: false,
                                  compact: true,
                                ),
                                const SizedBox(height: 12),
                                _MetricCard(
                                  title: 'Low Stock (Qty < 3)',
                                  value: '${metrics['lowStockCount'] ?? 0}',
                                  icon: Icons.notification_important_rounded,
                                  color: const Color(0xFFD32F2F),
                                  onTap: () => _showLowStockDetail(
                                    context,
                                    activeShop.id,
                                  ),
                                  isExpanded: false,
                                  compact: true,
                                ),
                                const SizedBox(height: 12),
                                _MetricCard(
                                  title: 'Trending Qty (30d)',
                                  value: '${metrics['trendingMaxQty'] ?? 0}',
                                  icon: Icons.trending_up_rounded,
                                  color: const Color(0xFF388E3C),
                                  onTap: () => _showTrendingDetail(
                                    context,
                                    activeShop.id,
                                  ),
                                  isExpanded: false,
                                  compact: true,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              _MetricCard(
                                title: 'Today Sales Qty',
                                value: '${metrics['todaySalesQty'] ?? 0}',
                                icon: Icons.analytics_rounded,
                                color: const Color(0xFF1976D2),
                                onTap: () => _showTodaySalesDetail(
                                  context,
                                  activeShop.id,
                                ),
                              ),
                              const SizedBox(width: 16),
                              _MetricCard(
                                title: 'Low Stock (Qty < 3)',
                                value: '${metrics['lowStockCount'] ?? 0}',
                                icon: Icons.notification_important_rounded,
                                color: const Color(0xFFD32F2F),
                                onTap: () =>
                                    _showLowStockDetail(context, activeShop.id),
                              ),
                              const SizedBox(width: 16),
                              _MetricCard(
                                title: 'Trending Qty (30d)',
                                value: '${metrics['trendingMaxQty'] ?? 0}',
                                icon: Icons.trending_up_rounded,
                                color: const Color(0xFF388E3C),
                                onTap: () =>
                                    _showTrendingDetail(context, activeShop.id),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Quick Operations',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                            childAspectRatio = 1.5;
                          }

                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: childAspectRatio,
                            children: [
                              _ActionCard(
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
                                onTap: () => context.push('/pricelist'),
                              ),
                              _ActionCard(
                                label: 'Manage Parties',
                                icon: Icons.group_add_rounded,
                                baseColor: const Color(0xFF00838F),
                                onTap: () => context.push('/parties'),
                              ),
                              _ActionCard(
                                label: 'Export Data',
                                icon: Icons.import_export_rounded,
                                baseColor: const Color(0xFF6A1B9A),
                                onTap: () => context.push('/export'),
                              ),
                              _ActionCard(
                                label: 'Folders',
                                icon: Icons.folder_shared_rounded,
                                baseColor: const Color(0xFFE91E63),
                                onTap: () =>
                                    context.push('/folder-distribution'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => ErrorView(
            error: err,
            onRetry: () => ref.invalidate(dashboardMetricsProvider),
          ),
        ),
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isExpanded;
  final bool compact;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isExpanded = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = RepaintBoundary(
      child: Container(
        width: isExpanded ? null : double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.85), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withValues(alpha: 0.1),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: compact ? 16 : 20,
              ),
              child: compact
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 16),
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
        ),
      ),
    );

    return isExpanded ? Expanded(child: content) : content;
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
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: baseColor.withValues(alpha: 0.1),
              highlightColor: baseColor.withValues(alpha: 0.05),
              child: Stack(
                children: [
                  Positioned(
                    top: -24,
                    right: -24,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: baseColor.withValues(alpha: 0.03),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -16,
                    right: -16,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Icon(
                        icon,
                        size: 90,
                        color: baseColor.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 24,
                    bottom: 24,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: baseColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: baseColor, size: 26),
                        ),
                        const Spacer(),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
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
    final detailAsync = ref.watch(dashboardDetailProvider(type));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: detailAsync.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return const Center(
                        child: Text(
                          'No records found.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _buildListItem(data[index]),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text(ErrorTranslator.translate(e))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    if (type == 'today_sales') {
      final designNo = (item['products_design'] as Map)['design_no'];
      final partyName = (item['parties'] as Map)['partyname'];
      final date = DateTime.parse(item['created_at']).formatIST('HH:mm');
      return Card(
        elevation: 0,
        color: AppColors.scaffoldBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: Text(
            'Design: $designNo',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('Party: $partyName @ $date'),
          trailing: Text(
            '${item['quantity']} Qty',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      );
    } else if (type == 'low_stock') {
      final designNo = (item['products_design'] as Map)['design_no'];
      final location = (item['locations'] as Map)['name'];
      return Card(
        elevation: 0,
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: Text(
            'Design: $designNo',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('Location: $location'),
          trailing: Text(
            '${item['quantity']} Qty',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
      );
    } else {
      // Trending
      return Card(
        elevation: 0,
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green,
            child: Text(
              '${item['quantity']}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            'Design: ${item['design_no']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Top Seller'),
        ),
      );
    }
  }
}

class _ShopSelectionView extends ConsumerStatefulWidget {
  const _ShopSelectionView();

  @override
  ConsumerState<_ShopSelectionView> createState() => _ShopSelectionViewState();
}

class _ShopSelectionViewState extends ConsumerState<_ShopSelectionView> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(shopsProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        image: DecorationImage(
          image: const AssetImage('images/pattern.png'),
          opacity: 0.03,
          repeat: ImageRepeat.repeat,
          onError: (exception, stackTrace) => {},
        ),
      ),
      child: shopsAsync.when(
        data: (List<Shop> allShops) {
          if (allShops.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(shopsProvider),
              color: AppColors.primary,
              child: Stack(
                children: [
                  ListView(), // Required for RefreshIndicator
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.store_mall_directory_outlined,
                          size: 80,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No shops available',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please contact your administrator to assign shops.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(shopsProvider),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Check Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Auto-select if ONLY ONE shop exists
          if (allShops.length == 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ref.read(activeShopProvider) == null) {
                ref.read(activeShopProvider.notifier).setShop(allShops.first);
              }
            });
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final crossAxisCount = isWide ? 2 : 1;
              final horizontalPadding = isWide
                  ? constraints.maxWidth * 0.15
                  : 24.0;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to ShopManage',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please select a workspace to continue your management.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 48),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        mainAxisExtent: 110,
                      ),
                      itemCount: allShops.length,
                      itemBuilder: (context, index) {
                        final shop = allShops[index];
                        final isHovered = _hoveredIndex == index;

                        final List<IconData> shopIcons = [
                          Icons.storefront_rounded,
                          Icons.shopping_bag_rounded,
                          Icons.apartment_rounded,
                          Icons.warehouse_rounded,
                        ];
                        final List<Color> shopColors = [
                          const Color(0xFF0F4C81),
                          const Color(0xFF2E7D32),
                          const Color(0xFFC62828),
                          const Color(0xFFEF6C00),
                        ];

                        final icon = shopIcons[index % shopIcons.length];
                        final color = shopColors[index % shopColors.length];

                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = index),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: RepaintBoundary(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform: isHovered
                                  ? (Matrix4.identity()..scale(1.015, 1.015))
                                  : Matrix4.identity(),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: isHovered
                                        ? color.withOpacity(0.12)
                                        : Colors.black.withOpacity(0.03),
                                    blurRadius: isHovered ? 16 : 8,
                                    offset: isHovered
                                        ? const Offset(0, 6)
                                        : const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: isHovered
                                      ? color.withOpacity(0.25)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => ref
                                      .read(activeShopProvider.notifier)
                                      .setShop(shop),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                color.withValues(alpha: 0.8),
                                                color,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: color.withOpacity(0.2),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            icon,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                shop.shopName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 18,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tap to open shop',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppColors.textSecondary
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: isHovered
                                              ? color
                                              : AppColors.divider.withValues(
                                                  alpha: 0.6,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
              SizedBox(height: 24),
              Text(
                'Syncing your workspaces...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
