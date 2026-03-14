import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/core_providers.dart';
import '../../services/export_service.dart';
import '../../services/log_service.dart';
import '../../theme/app_theme.dart';
import '../common/app_drawer.dart';
import '../common/app_bar_actions.dart';

enum DateFilter {
  today('Today', Icons.today_rounded),
  yesterday('Yesterday', Icons.history_rounded),
  last7Days('7 Days', Icons.date_range_rounded),
  last15Days('15 Days', Icons.update_rounded),
  currentMonth('This Month', Icons.calendar_month_rounded),
  currentFY('Current F.Y.', Icons.account_balance_rounded),
  custom('Custom', Icons.edit_calendar_rounded);

  final String label;
  final IconData icon;
  const DateFilter(this.label, this.icon);
}

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  DateFilter _selectedFilter = DateFilter.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isLoading = false;

  DateTime get _startDate {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case DateFilter.today:
        return DateTime(now.year, now.month, now.day);
      case DateFilter.yesterday:
        return DateTime(now.year, now.month, now.day - 1);
      case DateFilter.last7Days:
        return DateTime(now.year, now.month, now.day - 6);
      case DateFilter.last15Days:
        return DateTime(now.year, now.month, now.day - 14);
      case DateFilter.currentMonth:
        return DateTime(now.year, now.month, 1);
      case DateFilter.currentFY:
        final startYear = now.month < 4 ? now.year - 1 : now.year;
        return DateTime(startYear, 4, 1);
      case DateFilter.custom:
        return _customStartDate ?? DateTime(now.year, now.month, now.day);
    }
  }

  DateTime get _endDate {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case DateFilter.today:
      case DateFilter.last7Days:
      case DateFilter.last15Days:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DateFilter.yesterday:
        return DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
      case DateFilter.currentMonth:
        return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case DateFilter.currentFY:
        final startYear = now.month < 4 ? now.year - 1 : now.year;
        return DateTime(startYear + 1, 3, 31, 23, 59, 59);
      case DateFilter.custom:
        if (_customEndDate != null) {
          return DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
        }
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(start: DateTime.now(), end: DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedFilter = DateFilter.custom;
      });
    }
  }

  Future<void> _handleExport(Future<void> Function() exportTask, String name) async {
    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating $name...'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
    try {
      await exportTask();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             content: Row(
               children: [
                 const Icon(Icons.check_circle, color: Colors.white),
                 const SizedBox(width: 8),
                 Text('$name exported successfully!'),
               ],
             ),
             behavior: SnackBarBehavior.floating,
             backgroundColor: Colors.green.shade700,
          )
        );
      }
    } catch (e, stack) {
      ref.read(logServiceProvider).error('Export UI', 'Export button failed: $name', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        children: DateFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (filter == DateFilter.custom) {
                  _pickDateRange();
                } else {
                  setState(() => _selectedFilter = filter);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                    width: 1.2,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ] : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter.icon, 
                      size: 13, 
                      color: isSelected ? Colors.white : AppColors.primary.withValues(alpha: 0.7)
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filter.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateDisplay() {
    final startStr = DateFormat('dd MMM yyyy').format(_startDate);
    final endStr = DateFormat('dd MMM yyyy').format(_endDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FROM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(startStr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(endStr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onExcelTap,
    VoidCallback? onPdfTap,
    bool showDateRangeInfo = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -5,
              top: -5,
              child: Icon(
                icon,
                size: 90,
                color: color.withOpacity(0.04),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.8), color],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (showDateRangeInfo) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.filter_alt_rounded, size: 10, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            'Date filtered',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                          )
                        ],
                      ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FancyButton(
                          label: 'Export Excel',
                          icon: Icons.table_chart_rounded,
                          color: const Color(0xFF107C41), // Excel Green
                          onTap: _isLoading ? null : onExcelTap,
                        ),
                      ),
                      if (onPdfTap != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FancyButton(
                            label: 'Export PDF',
                            icon: Icons.picture_as_pdf_rounded,
                            color: const Color(0xFFD32F2F), // PDF Red
                            onTap: _isLoading ? null : onPdfTap,
                          ),
                        ),
                      ],
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeShop = ref.watch(activeShopProvider);
    final exportService = ref.watch(exportServiceProvider);

    if (activeShop == null) {
      return const Scaffold(body: Center(child: Text('Please select a workspace first.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // A very modern, slightly cool off-white
      appBar: AppBar(
        leadingWidth: 96,
        leading: Builder(builder: (context) {
          return Row(
            children: [
              const BackButton(color: AppColors.textPrimary),
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppColors.primary),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ],
          );
        }),
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeShop != null)
              Text(activeShop.shopName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
            Text(
              'Export Center',
              style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: const [AppBarActions()],
      ),
      drawer: const AppDrawer(currentRoute: '/export'),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Time Period',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.blueGrey.shade800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFilterChips(),
                    const SizedBox(height: 16),
                    _buildDateDisplay(),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Available Reports',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.blueGrey.shade800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _buildExportCard(
                            title: 'Sales Report',
                            description: 'Comprehensive list of all sales invoices, party names, and item quantities sold.',
                            icon: Icons.point_of_sale_rounded,
                            color: const Color(0xFF0F4C81),
                            onExcelTap: () => _handleExport(
                              () => exportService.exportSalesToExcel(
                                activeShop.id, activeShop.shopName,
                                startDate: _startDate, endDate: _endDate,
                              ),
                              'Sales Excel',
                            ),
                            onPdfTap: () => _handleExport(
                              () => exportService.exportSalesToPdf(
                                activeShop.id, activeShop.shopName,
                                startDate: _startDate, endDate: _endDate,
                              ),
                              'Sales PDF',
                            ),
                          ),
                          _buildExportCard(
                            title: 'Sales (Miracle Format)',
                            description: 'Accounting-ready format with specific columns for Miracle software import.',
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF673AB7),
                            onExcelTap: () => _handleExport(
                              () => exportService.exportSalesMiracleFormat(
                                activeShop.id, activeShop.shopName,
                                startDate: _startDate, endDate: _endDate,
                              ),
                              'Miracle Sales Excel',
                            ),
                          ),
                          _buildExportCard(
                            title: 'Purchase Report',
                            description: 'Detailed record of all purchases made, including supplier and material details.',
                            icon: Icons.add_shopping_cart_rounded,
                            color: const Color(0xFF2E7D32),
                            onExcelTap: () => _handleExport(
                              () => exportService.exportPurchaseToExcel(
                                activeShop.id, activeShop.shopName,
                                startDate: _startDate, endDate: _endDate,
                              ),
                              'Purchase Excel',
                            ),
                            onPdfTap: () => _handleExport(
                              () => exportService.exportPurchaseToPdf(
                                activeShop.id, activeShop.shopName,
                                startDate: _startDate, endDate: _endDate,
                              ),
                              'Purchase PDF',
                            ),
                          ),
                          _buildExportCard(
                            title: 'Current Stock',
                            description: 'A snapshot of your current live inventory across all locations. Not affected by date filter.',
                            icon: Icons.inventory_2_rounded,
                            color: const Color(0xFFE65100),
                            showDateRangeInfo: false,
                            onExcelTap: () => _handleExport(
                              () => exportService.exportStockToExcel(activeShop.id, activeShop.shopName),
                              'Stock Excel',
                            ),
                            onPdfTap: () => _handleExport(
                              () => exportService.exportStockToPdf(activeShop.id, activeShop.shopName),
                              'Stock PDF',
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, 20)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(strokeWidth: 4),
                            const SizedBox(height: 24),
                            Text(
                              'Generating Report...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please do not close this screen',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FancyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _FancyButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.85), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.2,
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
