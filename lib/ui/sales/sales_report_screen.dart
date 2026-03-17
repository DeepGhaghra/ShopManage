import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/sales_providers.dart';
import '../../services/party_providers.dart';
import '../../services/stock_providers.dart';
import '../../services/print_service.dart';
import '../../services/core_providers.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_scaffold.dart';
import '../common/empty_state_view.dart';
import '../common/error_view.dart';
import '../common/app_drawer.dart';
import '../../utils/date_utils.dart';
import '../../models/party.dart';
import '../../models/sales_entry.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupedSalesAsync = ref.watch(groupedRecentSalesProvider);
    final activeShop = ref.watch(activeShopProvider);
    final partiesAsync = ref.watch(partiesProvider);
    final stockAsync = ref.watch(shopStockProvider);

    return AdminScaffold(
      title: 'Sales Report',
      maxWidth: 1200,
      selectedShopId: activeShop?.id,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(recentSalesProvider),
          tooltip: 'Refresh',
        ),
      ],
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
      drawer: const AppDrawer(currentRoute: '/sales-report'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search by party name or invoice...',
                  hintStyle: TextStyle(color: AppColors.textHint, fontWeight: FontWeight.normal),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.cardSales, size: 22),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: groupedSalesAsync.when(
              data: (groupedSales) {
                final filteredGroups = groupedSales.entries.where((entry) {
                  final partyName = (entry.value.first.partyName ?? '').toLowerCase();
                  final invoiceNo = entry.key.toLowerCase();
                  return partyName.contains(_searchQuery) || invoiceNo.contains(_searchQuery);
                }).toList();

                // Sort by Date Descending (Latest first)
                filteredGroups.sort((a, b) {
                  final dateA = a.value.first.date;
                  final dateB = b.value.first.date;
                  return dateB.compareTo(dateA);
                });

                if (filteredGroups.isEmpty) {
                  return EmptyStateView(
                    title: _searchQuery.isEmpty ? 'No Sales Found' : 'No matches found',
                    message: _searchQuery.isEmpty 
                        ? 'Try selecting a different shop or creating a new sale.'
                        : 'No party matches your search query.',
                    icon: Icons.receipt_long_outlined,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(recentSalesProvider.future),
                  color: AppColors.cardSales,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final entry = filteredGroups[index];
                      final invoiceNo = entry.key;
                      final entries = entry.value;
                      final firstEntry = entries.first;
                      final totalSheets = entries.fold<int>(0, (sum, item) => sum + item.quantity);

                      return _ReportRow(
                        invoiceNo: invoiceNo,
                        date: firstEntry.date,
                        partyName: firstEntry.partyName ?? 'Unknown Party',
                        totalSheets: totalSheets,
                        onView: () => _showChallanDetails(context, entries, stockAsync.value),
                        onEdit: () {
                          context.push('/sales?edit=$invoiceNo');
                        },
                        onPrint: () async {
                          try {
                            final parties = partiesAsync.value;
                            final stock = stockAsync.value;

                            if (parties == null || stock == null || activeShop == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Data still loading...')),
                              );
                              return;
                            }

                            final party = parties.where((p) => p.id == firstEntry.partyId).firstOrNull ??
                                Party(
                                  id: firstEntry.partyId,
                                  partyName: firstEntry.partyName ?? 'Unknown',
                                  timeAdded: DateTime.now().toIST(),
                                  shopId: firstEntry.shopId,
                                );

                            final challanLines = entries.map((e) {
                              String bName = e.brandName ?? '';
                              String lName = e.locationName ?? '';
                              String dNo = e.designNo ?? '';

                              if (bName.isEmpty || lName.isEmpty || dNo.isEmpty) {
                                try {
                                  final s = stock.firstWhere((s) =>
                                      (s['products_design']?['id'] as int?) == e.designId &&
                                      (s['locations']?['id'] as int?) == e.locationId);
                                  
                                  if (bName.isEmpty) {
                                    bName = (s['products_design']?['product_head']?['folders']?['folder_name'] as String?) ??
                                            (s['products_design']?['product_head']?['product_name'] as String?) ?? '';
                                  }
                                  if (lName.isEmpty) lName = (s['locations']?['name'] as String?) ?? '';
                                  if (dNo.isEmpty) dNo = (s['products_design']?['design_no'] as String?) ?? e.designId.toString();
                                } catch (_) {
                                  if (lName.isEmpty) lName = 'Loc#${e.locationId}';
                                  if (dNo.isEmpty) dNo = 'Design#${e.designId}';
                                }
                              }

                              return ChallanLine(
                                brandName: bName,
                                locationName: lName,
                                designNo: dNo,
                                quantity: e.quantity,
                              );
                            }).toList();

                            await ref.read(printServiceProvider).printSalesInvoice(
                              shop: activeShop,
                              party: party,
                              invoiceNo: invoiceNo,
                              lines: challanLines,
                              date: firstEntry.date,
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Print Error: $e')),
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => ErrorView(
                error: err,
                onRetry: () => ref.invalidate(recentSalesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChallanDetails(BuildContext context, List<SalesEntry> entries, List<Map<String, dynamic>>? stock) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Challan Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'INV: ${entries.first.invoiceno} • ${entries.first.date.formatDateIST()} • ${entries.first.partyName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final e = entries[index];
                  String bName = e.brandName ?? '';
                  String lName = e.locationName ?? '';
                  String dNo = e.designNo ?? '';

                  if (bName.isEmpty || lName.isEmpty || dNo.isEmpty) {
                    try {
                      final s = stock?.firstWhere((s) =>
                          (s['products_design']?['id'] as int?) == e.designId &&
                          (s['locations']?['id'] as int?) == e.locationId);
                      
                      if (bName.isEmpty) {
                        bName = (s?['products_design']?['product_head']?['folders']?['folder_name'] as String?) ??
                                (s?['products_design']?['product_head']?['product_name'] as String?) ?? '';
                      }
                      if (lName.isEmpty) lName = (s?['locations']?['name'] as String?) ?? '';
                      if (dNo.isEmpty) dNo = (s?['products_design']?['design_no'] as String?) ?? e.designId.toString();
                    } catch (_) {
                      if (lName.isEmpty) lName = 'Loc#${e.locationId}';
                      if (dNo.isEmpty) dNo = 'Design#${e.designId}';
                    }
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            color: AppColors.cardSales.withOpacity(0.3),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dNo,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            color: AppColors.textPrimary,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 8,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.folder_copy_rounded, size: 14, color: AppColors.textSecondary),
                                                const SizedBox(width: 6),
                                                Text(
                                                  bName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.location_on_rounded, size: 14, color: Colors.orange.shade700),
                                                const SizedBox(width: 6),
                                                Text(
                                                  lName,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.orange.shade900,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardSales.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'QTY',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.cardSales.withOpacity(0.7),
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        Text(
                                          '${e.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 22,
                                            color: AppColors.cardSales,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String invoiceNo;
  final DateTime date;
  final String partyName;
  final int totalSheets;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onPrint;

  const _ReportRow({
    required this.invoiceNo,
    required this.date,
    required this.partyName,
    required this.totalSheets,
    required this.onView,
    required this.onEdit,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left Accent
            Container(
              width: 5,
              color: AppColors.cardSales,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Inv + Party Name + Qty
                          Row(
                            children: [
                              _InvoiceBadge(invoiceNo: invoiceNo),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  partyName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SheetQty(qty: totalSheets),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Row 2: Date + Actions
                          Row(
                            children: [
                              Text(
                                date.formatDateIST(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary.withOpacity(0.5),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              _ActionButton(
                                icon: Icons.visibility_rounded,
                                color: Colors.deepPurple,
                                onPressed: onView,
                              ),
                              const SizedBox(width: 4),
                              _ActionButton(
                                icon: Icons.edit_document,
                                color: Colors.blue.shade700,
                                onPressed: onEdit,
                              ),
                              const SizedBox(width: 4),
                              _ActionButton(
                                icon: Icons.print_rounded,
                                color: Colors.teal.shade700,
                                onPressed: onPrint,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Date & Invoice
                          SizedBox(
                            width: 140,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  date.formatDateIST(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _InvoiceBadge(invoiceNo: invoiceNo),
                              ],
                            ),
                          ),
                          
                          // Party Name
                          Expanded(
                            flex: 3,
                            child: Text(
                              partyName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Quantity Metric
                          Expanded(
                            flex: 2,
                            child: Center(child: _SheetQty(qty: totalSheets)),
                          ),
                          
                          // Actions
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              _ActionButton(
                                icon: Icons.visibility_rounded,
                                color: Colors.deepPurple,
                                onPressed: onView,
                                label: 'View',
                              ),
                              const SizedBox(width: 8),
                              _ActionButton(
                                icon: Icons.edit_document,
                                color: Colors.blue.shade700,
                                onPressed: onEdit,
                                label: 'Edit',
                              ),
                              const SizedBox(width: 8),
                              _ActionButton(
                                icon: Icons.print_rounded,
                                color: Colors.teal.shade700,
                                onPressed: onPrint,
                                label: 'Print',
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceBadge extends StatelessWidget {
  final String invoiceNo;
  const _InvoiceBadge({required this.invoiceNo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardSales.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardSales.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.confirmation_number_rounded, size: 10, color: AppColors.cardSales),
          const SizedBox(width: 4),
          Text(
            invoiceNo,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              color: AppColors.cardSales,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetQty extends StatelessWidget {
  final int qty;
  const _SheetQty({required this.qty});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardSales.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QTY:',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.cardSales.withOpacity(0.5),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$qty',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.cardSales,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TOTAL SHEETS',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary.withOpacity(0.6),
              letterSpacing: 0.8,
            ),
          ),
          Text(
            '$qty',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? label;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label!,
        style: TextStyle(
          color: color, 
          fontWeight: FontWeight.w900, 
          fontSize: 13,
          letterSpacing: -0.2,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.08),
        foregroundColor: color,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(color.withOpacity(0.05)),
      ),
    );
  }
}
