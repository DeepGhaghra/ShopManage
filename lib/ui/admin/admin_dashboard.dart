import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/core_providers.dart';
import 'package:shopmanage/theme/app_theme.dart';
import '../common/app_drawer.dart';
import 'admin_scaffold.dart';
import 'dart:ui';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeShop = ref.watch(activeShopProvider);

    return AdminScaffold(
      title: 'Admin Console',
      backgroundColor: const Color(0xFFF3F4F6), // Cool light gray, classic web dashboard BG
      drawer: const AppDrawer(currentRoute: '/admin'),
      selectedShopId: activeShop?.id,
      onShopChanged: (val) {
        if (val == null) {
          ref.read(activeShopProvider.notifier).setShop(null);
        } else {
          final shopsAsync = ref.read(associatedShopsProvider);
          shopsAsync.whenData((shops) {
            final shop = shops.firstWhere((s) => s.id == val);
            ref.read(activeShopProvider.notifier).setShop(shop);
          });
        }
      },
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shopsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            children: [
              // Edge-to-edge premium hero banner
              _buildModernHero(),
              
              // Centered content body
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Global Operations', 'Manage your central infrastructure & resources.'),
                        const SizedBox(height: 24),
                        _buildResponsiveCardGrid(context),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHero() {
    return Builder(
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 32, vertical: isMobile ? 16 : 32),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 14 : 20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
                      ),
                      child: Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: isMobile ? 32 : 48),
                    ),
                    SizedBox(width: isMobile ? 16 : 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Master Workspace',
                            style: TextStyle(
                              color: const Color(0xFF111827), // Gray 900
                              fontSize: isMobile ? 22 : 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                          ),
                          SizedBox(height: isMobile ? 4 : 6),
                          Text(
                            'A centralized hub to configure, manage, and monitor all your systems globally.',
                            style: TextStyle(
                              color: const Color(0xFF6B7280), // Gray 500
                              fontSize: isMobile ? 13 : 16,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
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
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveCardGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isMobile = availableWidth < 500;
        final isTablet = availableWidth >= 500 && availableWidth < 900;
        
        int cols = isMobile ? 1 : (isTablet ? 2 : (availableWidth < 1200 ? 3 : 4));
        double spacing = isMobile ? 16.0 : 24.0;
        double totalSpacing = spacing * (cols - 1);
        double cardWidth = (availableWidth - totalSpacing) / cols;
        // prevent cards from becoming incredibly thin or wide
        cardWidth = cardWidth.clamp(140.0, availableWidth);


        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _ModernDashCard(
              title: 'Folders',
              description: 'Manage master categories and group structures.',
              icon: Icons.folder_copy_rounded,
              color: const Color(0xFF6366F1), // Indigo
              targetRoute: '/admin/folders',
              width: cardWidth,
            ),
            _ModernDashCard(
              title: 'Products',
              description: 'Configure head names, default specs & materials.',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF10B981), // Emerald
              targetRoute: '/admin/products',
              width: cardWidth,
            ),
            _ModernDashCard(
              title: 'Locations',
              description: 'Define sourcing sites and geographical regions.',
              icon: Icons.location_on_rounded,
              color: const Color(0xFFF43F5E), // Rose
              targetRoute: '/admin/locations',
              width: cardWidth,
            ),
            _ModernDashCard(
              title: 'Shops',
              description: 'Maintain the database of all retail outlets.',
              icon: Icons.storefront_rounded,
              color: const Color(0xFFF59E0B), // Amber
              targetRoute: '/admin/shops',
              width: cardWidth,
            ),
          ],
        );
      }
    );
  }
}

class _ModernDashCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String targetRoute;
  final double width;

  const _ModernDashCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.targetRoute,
    required this.width,
  });

  @override
  State<_ModernDashCard> createState() => _ModernDashCardState();
}

class _ModernDashCardState extends State<_ModernDashCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Provide a reasonable fixed width to cards so they look like solid web components
    // On extremely small screens, they will shrink to fit using LayoutBuilder,
    // but on desktop they maintain a premium shape.
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push(widget.targetRoute),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: widget.width, // Dynamically assigned width from parent Wrap logic
          transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHovered ? widget.color.withOpacity(0.4) : const Color(0xFFF3F4F6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                    ? widget.color.withOpacity(0.15) 
                    : Colors.black.withOpacity(0.03),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 10 : 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16), // Tighter padding for space saving
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isHovered ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF9FAFB),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded, 
                          color: widget.color, 
                          size: 14
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.description,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

