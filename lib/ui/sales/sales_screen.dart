import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/sales_providers.dart';
import '../../services/party_providers.dart';
import '../../services/print_service.dart';
import '../../services/stock_providers.dart';
import '../../models/party.dart';
import '../../models/sales_entry.dart';
import '../../services/core_providers.dart';
import '../../theme/app_theme.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class _SaleItemLine {
  /// Holds one merged stock row: {products_design, locations, quantity}
  Map<String, dynamic>? stockRow;

  int    get locationId    => (stockRow?['locations']?['id']  as int?)    ?? 0;
  String get locationName  => (stockRow?['locations']?['name'] as String?) ?? '';
  int    get maxQuantity   => (stockRow?['quantity']           as int?)    ?? 0;
  int    get rate          => ((stockRow?['products_design']?['product_head']?['product_rate']) as int?) ?? 0;
  int    get designId      => (stockRow?['products_design']?['id'] as int?)           ?? 0;
  String get designNo      => (stockRow?['products_design']?['design_no'] as String?) ?? '';
  int    get productHeadId => (stockRow?['products_design']?['product_head_id'] as int?) ?? 0;

  int quantity = 1;
  int get total => quantity * rate;
}

// ─── Widget ───────────────────────────────────────────────────────────────────
class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _invoiceController = TextEditingController();
  Party? _selectedParty;

  final List<_SaleItemLine> _lines = [_SaleItemLine()];
  bool _isSaving = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchNextInvoiceNo());
  }

  Future<void> _fetchNextInvoiceNo() async {
    final activeShop = ref.read(activeShopProvider);
    if (activeShop == null) return;
    setState(() => _isInitializing = true);
    try {
      final invNo = await ref.read(salesRepositoryProvider).generateInvoiceNo(activeShop.id);
      _invoiceController.text = invNo;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate invoice no: $e')));
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_SaleItemLine()));

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      if (_lines.isEmpty) _lines.add(_SaleItemLine());
    });
  }

  Future<void> _saveAndPrint() async {
    if (_invoiceController.text.isEmpty || _selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Invoice No and Party.')));
      return;
    }

    for (var line in _lines) {
      if (line.stockRow == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Design for all items.')));
        return;
      }
      if (line.quantity <= 0 || line.quantity > line.maxQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid quantity for ${line.designNo}.')));
        return;
      }
    }

    final activeShop = ref.read(activeShopProvider);
    if (activeShop == null) return;

    setState(() => _isSaving = true);

    try {
      final entries = _lines.map((line) {
        return SalesEntry(
          id: 0,
          date: DateTime.now(),
          invoiceno: _invoiceController.text.trim(),
          partyId: _selectedParty!.id,
          productId: line.productHeadId,
          designId: line.designId,
          locationId: line.locationId,
          quantity: line.quantity,
          rate: line.rate,
          amount: line.total,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          shopId: activeShop.id,
        );
      }).toList();

      await ref.read(salesRepositoryProvider).saveSalesInvoice(entries);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sale saved successfully! Printing...'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        ref.invalidate(recentSalesProvider);
        ref.invalidate(shopStockProvider); // refresh stock counts

        ref.read(printServiceProvider).printSalesInvoice(
          shop: activeShop,
          party: _selectedParty!,
          invoiceNo: _invoiceController.text.trim(),
          entries: entries,
        );

        _fetchNextInvoiceNo();
        setState(() {
          _selectedParty = null;
          _lines.clear();
          _lines.add(_SaleItemLine());
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving sale: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final recentSalesAsync = ref.watch(recentSalesProvider);
    final partiesAsync     = ref.watch(partiesProvider);
    final stockAsync       = ref.watch(shopStockProvider);

    final isWide = MediaQuery.of(context).size.width > 900;

    Widget formContent = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade200)),
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), shape: BoxShape.circle),
                  child: const Icon(Icons.shopping_cart_checkout, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Text('Create Invoice', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Invoice No + Party ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _invoiceController,
                    readOnly: true,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Invoice Number',
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      prefixIcon: const Icon(Icons.receipt_long, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // ── Searchable Party ────────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: partiesAsync.when(
                    data: (parties) {
                      return Autocomplete<Party>(
                        initialValue: TextEditingValue(text: _selectedParty?.partyName ?? ''),
                        displayStringForOption: (p) => p.partyName,
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return parties;
                          return parties.where((p) => p.partyName.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (party) => setState(() => _selectedParty = party),
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            validator: (_) => _selectedParty == null ? 'Please select a party' : null,
                            decoration: InputDecoration(
                              labelText: 'Search Party',
                              labelStyle: TextStyle(color: Colors.grey.shade600),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.business, color: AppColors.primary),
                              suffixIcon: const Icon(Icons.search_rounded, color: AppColors.accent),
                            ),
                            onFieldSubmitted: (_) => onFieldSubmitted(),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white,
                              clipBehavior: Clip.antiAlias,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final party = options.elementAt(index);
                                    return InkWell(
                                      onTap: () => onSelected(party),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                                              child: const Icon(Icons.business, size: 16, color: AppColors.primary),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(party.partyName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                                  if (party.city?.isNotEmpty ?? false)
                                                    Text(party.city!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('Error loading parties: $err'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Order Items Header ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ElevatedButton.icon(
                  onPressed: _addLine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withAlpha(20),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Row'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Items ───────────────────────────────────────────────────────
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final line = _lines[index];
                return _buildItemRow(index, line, stockAsync);
              },
            ),
            const SizedBox(height: 16),

            // ── Grand Total + Save ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Grand Total', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(
                        'Rs. ${_lines.fold<int>(0, (sum, l) => sum + l.total)}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAndPrint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print),
                    label: const Text('Save & Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
    );

    // ── Recent Sales Panel ────────────────────────────────────────────────────
    Widget recentSalesContent = Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade200)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            recentSalesAsync.when(
              data: (sales) {
                if (sales.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('No sales yet', style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withAlpha(15),
                        child: const Icon(Icons.receipt, size: 16, color: AppColors.primary),
                      ),
                      title: Text(sale.invoiceno, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(sale.date.toString().substring(0, 10), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      trailing: Text('Rs.${sale.amount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    );
                  },
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())),
              error: (err, stack) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales Challan', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            if (ref.watch(activeShopProvider) != null)
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    ref.watch(activeShopProvider)!.shopName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent),
                  ),
                ],
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: SingleChildScrollView(child: formContent)),
                Expanded(flex: 2, child: SingleChildScrollView(child: recentSalesContent)),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  formContent,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: recentSalesContent,
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Item Row with Unified Stock Search ─────────────────────────────────────
  Widget _buildItemRow(int index, _SaleItemLine line, AsyncValue<List<Map<String, dynamic>>> stockAsync) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row number badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withAlpha(12), shape: BoxShape.circle),
            child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Unified Design + Location + Stock Search ───────────────
                stockAsync.when(
                  data: (stockRows) {
                    final available = stockRows.where((r) => (r['quantity'] as int? ?? 0) > 0).toList();
                    return Autocomplete<Map<String, dynamic>>(
                      initialValue: line.stockRow != null
                          ? TextEditingValue(text: '${line.designNo}  |  ${line.locationName}  |  ${line.maxQuantity}')
                          : TextEditingValue.empty,
                      displayStringForOption: (row) {
                        final d = row['products_design']?['design_no'] as String? ?? '';
                        final l = row['locations']?['name']        as String? ?? '';
                        final q = row['quantity']                  as int?    ?? 0;
                        return '$d  |  $l  |  $q';
                      },
                      optionsBuilder: (tv) {
                        if (tv.text.isEmpty) return available;
                        final q = tv.text.toLowerCase();
                        return available.where((r) {
                          final d = (r['products_design']?['design_no'] as String? ?? '').toLowerCase();
                          final l = (r['locations']?['name'] as String? ?? '').toLowerCase();
                          return d.contains(q) || l.contains(q);
                        });
                      },
                      onSelected: (row) => setState(() { line.stockRow = row; line.quantity = 1; }),
                      fieldViewBuilder: (context, ctrl, focusNode, onSub) {
                        return TextFormField(
                          controller: ctrl,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Search Design  |  Location  |  Stock',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.manage_search_rounded, color: AppColors.accent),
                            suffixIcon: line.stockRow != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      ctrl.clear();
                                      setState(() { line.stockRow = null; line.quantity = 1; });
                                    },
                                  )
                                : null,
                          ),
                          onFieldSubmitted: (_) => onSub(),
                        );
                      },
                      optionsViewBuilder: (context, onSel, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                            clipBehavior: Clip.antiAlias,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 520),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Column headers
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    color: AppColors.primary.withAlpha(12),
                                    child: const Row(
                                      children: [
                                        Expanded(flex: 3, child: Text('Design No', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent))),
                                        Expanded(flex: 2, child: Text('Location',  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent))),
                                        Text('Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, idx) {
                                        final row   = options.elementAt(idx);
                                        final dNo   = row['products_design']?['design_no'] as String? ?? '';
                                        final lName = row['locations']?['name']        as String? ?? '';
                                        final qty   = row['quantity']                  as int?    ?? 0;
                                        final isLow = qty < 5;
                                        return InkWell(
                                          onTap: () => onSel(row),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(dNo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.location_on, size: 13, color: Colors.grey.shade400),
                                                      const SizedBox(width: 2),
                                                      Text(lName, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isLow ? Colors.orange.shade50 : Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: isLow ? Colors.orange.shade200 : Colors.green.shade200),
                                                  ),
                                                  child: Text(
                                                    '$qty',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: isLow ? Colors.orange.shade700 : Colors.green.shade700,
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
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),

                // ── Location chip + Qty + Total (shown after selection) ────
                if (line.stockRow != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(line.locationName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Text('Available: ${line.maxQuantity}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const Spacer(),
                        Text('Rate: Rs.${line.rate}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('qty_${index}_${line.designId}_${line.locationId}'),
                          initialValue: line.quantity.toString(),
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            isDense: true,
                            helperText: 'Max: ${line.maxQuantity}',
                            helperStyle: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            prefixIcon: const Icon(Icons.numbers, size: 18),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final q = int.tryParse(v ?? '') ?? 0;
                            if (q <= 0) return 'Min 1';
                            if (q > line.maxQuantity) return 'Max ${line.maxQuantity}';
                            return null;
                          },
                          onChanged: (v) {
                            final q = int.tryParse(v) ?? 1;
                            setState(() { line.quantity = q.clamp(1, line.maxQuantity > 0 ? line.maxQuantity : 9999); });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          children: [
                            const Text('Total', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text('Rs.${line.total}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Delete row button
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
            onPressed: () => _removeLine(index),
            tooltip: 'Remove row',
          ),
        ],
      ),
    );
  }
}