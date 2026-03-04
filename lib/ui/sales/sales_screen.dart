import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/sales_providers.dart';
import '../../services/party_providers.dart';
import '../../services/print_service.dart';
import '../../services/stock_providers.dart';
import '../../models/party.dart';
import '../../models/sales_entry.dart';
import '../../models/pricelist.dart';
import '../../services/core_providers.dart';
import '../../services/log_service.dart';
import '../../theme/app_theme.dart';
import '../common/confirmation_dialog.dart';
import '../common/loading_overlay.dart';
import '../common/error_view.dart';
import '../common/empty_state_view.dart';
import '../../utils/error_translator.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class _SaleItemLine {
  /// Holds one merged stock row: {products_design, locations, quantity}
  Map<String, dynamic>? stockRow;

  T? _getData<T>(dynamic data) {
    if (data == null) return null;
    if (data is List) return data.isEmpty ? null : data.first as T?;
    if (data is Map) return data as T?;
    return null;
  }

  int get locationId {
    final loc = _getData<Map<String, dynamic>>(stockRow?['locations']);
    return (loc?['id'] as int?) ?? 0;
  }

  String get locationName {
    final loc = _getData<Map<String, dynamic>>(stockRow?['locations']);
    return (loc?['name'] as String?) ?? '';
  }

  int get maxQuantity => (stockRow?['quantity'] as int?) ?? 0;

  int get rate {
    final pd = _getData<Map<String, dynamic>>(stockRow?['products_design']);
    final head = _getData<Map<String, dynamic>>(pd?['product_head']);
    return (head?['product_rate'] as int?) ?? 0;
  }

  int get designId {
    final pd = _getData<Map<String, dynamic>>(stockRow?['products_design']);
    return (pd?['id'] as int?) ?? 0;
  }

  String get designNo {
    final pd = _getData<Map<String, dynamic>>(stockRow?['products_design']);
    return (pd?['design_no'] as String?) ?? '';
  }

  int get productHeadId {
    final pd = _getData<Map<String, dynamic>>(stockRow?['products_design']);
    return (pd?['product_head_id'] as int?) ?? 0;
  }

  String get brandName {
    final pd = _getData<Map<String, dynamic>>(stockRow?['products_design']);
    final head = _getData<Map<String, dynamic>>(pd?['product_head']);
    final folder = _getData<Map<String, dynamic>>(head?['folders']);
    return (folder?['folder_name'] as String?) ?? (head?['product_name'] as String?) ?? '';
  }

  int quantity = 1;
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController();

  int get currentRate => int.tryParse(rateController.text) ?? 0;
  int get total => quantity * currentRate;

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
  }
}

// ─── Helper for Memoization ──────────────────────────────────────────────────
T useMemoized<T>(T Function() factory, List<Object?> keys) {
  // Simple manual memoization since we aren't using hooks
  return factory();
}


// ─── Widget ───────────────────────────────────────────────────────────────────
class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _invoiceController = TextEditingController();
  final _partySearchController = TextEditingController(); // Fixed: Added controller for party search
  Party? _selectedParty;

  final List<_SaleItemLine> _lines = [_SaleItemLine()];
  String? _editingInvoiceNo;
  bool _isSaving = false;
  bool _isInitializing = false;
  int _formResetKey = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchNextInvoiceNo());
  }

  Future<void> _fetchNextInvoiceNo() async {
    if (_editingInvoiceNo != null) return;
    final activeShop = ref.read(activeShopProvider);
    if (activeShop == null) return;
    setState(() => _isInitializing = true);
    try {
      final invNo = await ref.read(salesRepositoryProvider).generateInvoiceNo(activeShop.id);
      _invoiceController.text = invNo;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorTranslator.translate(e))));
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    for (var line in _lines) { line.dispose(); }
    _invoiceController.dispose();
    _partySearchController.dispose();
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_SaleItemLine()));

  Future<void> _removeLine(int index) async {
    final line = _lines[index];
    if (line.stockRow != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => ConfirmationDialog(
          title: 'Remove Item?',
          message: 'Are you sure you want to remove ${line.designNo} from this sale?',
          confirmLabel: 'Remove',
          confirmColor: Colors.red,
          icon: Icons.delete_outline,
        ),
      );
      if (confirm != true) return;
    }
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
      if (_lines.isEmpty) _lines.add(_SaleItemLine());
    });
  }

  void _loadInvoiceForEdit(String invoiceNo, List<SalesEntry> entries, List<Party> parties, List<Map<String, dynamic>> allStock) {
    setState(() {
      _editingInvoiceNo = invoiceNo;
      _invoiceController.text = invoiceNo;
      _formResetKey++; // Force all Autocomplete widgets to refresh their initialValue
      
      // Try to re-hydrate party
      if (entries.isNotEmpty) {
         try {
           _selectedParty = parties.firstWhere((p) => p.id == entries.first.partyId);
           _partySearchController.text = _selectedParty?.partyName ?? ''; // Fix: Update the search field text
         } catch (e) {
           _selectedParty = null;
           _partySearchController.text = '';
         }
      }

      // Re-hydrate lines
      for (var l in _lines) l.dispose();
      _lines.clear();
      for (var entry in entries) {
        final line = _SaleItemLine();
        line.quantity = entry.quantity;
        line.qtyController.text = entry.quantity.toString();
        line.rateController.text = entry.rate.toString();
        
        // Find matching stock to prepopulate Design & Location.
        try {
           final matchedStock = allStock.firstWhere((s) {
               final stockDesignId = (s['products_design']?['id'] as int?);
               final stockLocationId = (s['locations']?['id'] as int?);
               return stockDesignId == entry.designId && stockLocationId == entry.locationId;
           });
           
           final stockCopy = Map<String, dynamic>.from(matchedStock);
           // Also add back the already-sold quantity so the user can see full available range.
           stockCopy['quantity'] = (stockCopy['quantity'] as int) + entry.quantity;
           
           line.stockRow = stockCopy;
        } catch (e) {
           // If stock not found in current shop cache (e.g. out of stock), create a mock row from the joined entry metadata
            line.stockRow = {
              'quantity': entry.quantity,
              'search_key': '${(entry.designNo ?? '').toLowerCase()} ${(entry.locationName ?? '').toLowerCase()}',
              'locations': {'id': entry.locationId, 'name': entry.locationName ?? 'Loc#${entry.locationId}'},
              'products_design': {
                'id': entry.designId,
                'design_no': entry.designNo ?? 'Design#${entry.designId}',
                'product_head_id': entry.productId,
                'product_head': {
                  'product_name': entry.brandName ?? '',
                  'product_rate': entry.rate,
                  'folders': {'folder_name': entry.brandName ?? ''}
                }
              }
            };
        }
        
        _lines.add(line);
      }
      
      if (_lines.isEmpty) _lines.add(_SaleItemLine());
    });
  }

  Future<void> _cancelEdit() async {
    if (_lines.any((l) => l.stockRow != null) || _selectedParty != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => const ConfirmationDialog(
          title: 'Discard Invoice?',
          message: 'Are you sure you want to discard this invoice? All entered data will be lost.',
          confirmLabel: 'Discard',
          confirmColor: Colors.red,
          icon: Icons.warning_amber_rounded,
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _editingInvoiceNo = null;
      _selectedParty = null;
      _partySearchController.clear();
      for (var l in _lines) l.dispose();
      _lines.clear();
      _lines.add(_SaleItemLine());
      _formResetKey++; 
    });
    _fetchNextInvoiceNo();
  }

  Future<void> _saveChallan({bool print = false}) async {
    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Party.')));
      return;
    }

    final seen = <String>{};
    for (var line in _lines) {
      if (line.stockRow == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Design for all items.')));
        return;
      }
      if (line.quantity <= 0 || line.quantity > line.maxQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid quantity for ${line.designNo}.')));
        return;
      }
      
      final key = '${line.designId}_${line.locationId}';
      if (seen.contains(key)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duplicate entry found: ${line.designNo} at ${line.locationName}. Please remove duplicates.')));
        return;
      }
      seen.add(key);
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
          partyName: _selectedParty!.partyName,
          brandName: line.brandName,
          locationName: line.locationName,
          designNo: line.designNo,
          productId: line.productHeadId,
          designId: line.designId,
          locationId: line.locationId,
          quantity: line.quantity,
          rate: line.currentRate,
          amount: line.total,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          shopId: activeShop.id,
        );
      }).toList();

      // Update pricelist for each item
      for (var line in _lines) {
        if (line.stockRow != null) {
          await ref.read(salesRepositoryProvider).upsertPricelist(Pricelist(
            productId: line.productHeadId,
            partyId: _selectedParty!.id,
            price: line.currentRate,
            shopId: activeShop.id,
          ));
        }
      }

      if (_editingInvoiceNo != null) {
        await ref.read(salesRepositoryProvider).updateSalesInvoice(_editingInvoiceNo!, entries);
      } else {
        await ref.read(salesRepositoryProvider).saveSalesInvoice(entries);
      }

      if (mounted) {
        ref.read(logServiceProvider).success(
          'Sales', 
          _editingInvoiceNo != null 
            ? 'Invoice "${_invoiceController.text.trim()}" updated (${_lines.length} items)' 
            : 'Invoice "${_invoiceController.text.trim()}" created (${_lines.length} items)',
          'Party: ${_selectedParty!.partyName}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingInvoiceNo != null ? 'Challan updated successfully!' : 'Challan saved successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        ref.invalidate(recentSalesProvider);
        ref.invalidate(shopStockProvider); // refresh stock counts

        if (print) {
          final challanLines = _lines.map((l) => ChallanLine(
            brandName: l.brandName,
            locationName: l.locationName,
            designNo: l.designNo,
            quantity: l.quantity,
          )).toList();
          ref.read(printServiceProvider).printSalesInvoice(
            shop: activeShop,
            party: _selectedParty!,
            invoiceNo: _invoiceController.text.trim(),
            lines: challanLines,
          );
        }

        setState(() {
          _editingInvoiceNo = null;
          _selectedParty = null;
          _partySearchController.clear(); // Fixed: Clear the search field
          _lines.clear();
          _lines.add(_SaleItemLine());
        });
        _fetchNextInvoiceNo();
      }
    } catch (e, stack) {
      ref.read(logServiceProvider).error('Sales', 'Failed to save invoice "${_invoiceController.text.trim()}"', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorTranslator.translate(e)),
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

    final recentSalesAsync = ref.watch(groupedRecentSalesProvider);
    final partiesAsync     = ref.watch(partiesProvider);
    final stockAsync       = ref.watch(shopStockProvider);

    // ── Optimized: Pre-calculate set of used design_location pairs ──
    // ── Optimized MERGE logic: Calculated only when base data changes ──
    final List<Map<String, dynamic>> availableStock = useMemoized(() {
      final List<Map<String, dynamic>> globalStock = stockAsync.maybeWhen(
        data: (rows) => rows, 
        orElse: () => [],
      );
      
      final Map<String, Map<String, dynamic>> map = {
        for (var s in globalStock) '${s['products_design']?['id']}_${s['locations']?['id']}': s
      };
      
      for (var line in _lines) {
        if (line.stockRow != null) {
          final key = '${line.designId}_${line.locationId}';
          if (!map.containsKey(key)) map[key] = line.stockRow!;
        }
      }
      return map.values.toList();
    }, [stockAsync.value, _lines.length, _formResetKey]); // Re-calculate only when fundamental counts change

    final Set<String> usedStockKeys = _lines
        .where((l) => l.stockRow != null)
        .map((l) => '${l.designId}_${l.locationId}')
        .toSet();

    final isWide = MediaQuery.of(context).size.width > 900;

    Widget formContent = Card(
      elevation: 0,
      color: _editingInvoiceNo != null ? const Color(0xFFF0F9FF) : Colors.white, // Light blue for edit
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24), 
        side: BorderSide(
          color: _editingInvoiceNo != null ? Colors.blue.shade200 : Colors.grey.shade200,
          width: _editingInvoiceNo != null ? 1.5 : 1.0,
        ),
      ),
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
                  child: Icon(_editingInvoiceNo != null ? Icons.edit_document : Icons.shopping_cart_checkout, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _editingInvoiceNo != null ? 'Update Sales' : 'Create Invoice', 
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                          ),
                          if (_editingInvoiceNo != null) ...[
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: _cancelEdit,
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              label: const Text('Cancel Edit', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_editingInvoiceNo != null)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50, 
                            borderRadius: BorderRadius.circular(6), 
                            border: Border.all(color: Colors.blue.shade200, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note, size: 14, color: Colors.blue.shade900),
                              const SizedBox(width: 4),
                              Text('EDITING: $_editingInvoiceNo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.blue.shade900)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
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
                        key: ValueKey('party_auto_${_editingInvoiceNo}'), // Removed _formResetKey from here to keep it stable
                        optionsMaxHeight: 250,
                        displayStringForOption: (p) => p.partyName,
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return parties;
                          return parties.where((p) => p.partyName.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (party) {
                          setState(() {
                            _selectedParty = party;
                            _partySearchController.text = party.partyName;
                          });
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          // Sync the Autocomplete's internal controller with our persistent one
                          if (controller.text != _partySearchController.text && _selectedParty != null) {
                            Future.microtask(() => controller.text = _partySearchController.text);
                          }


                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Search Party',
                              labelStyle: TextStyle(color: AppColors.primary.withAlpha(180)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.business_center_rounded, color: AppColors.primary),
                              suffixIcon: (controller.text.isNotEmpty) 
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18), 
                                    onPressed: () {
                                      controller.clear();
                                      _partySearchController.clear();
                                      setState(() => _selectedParty = null);
                                    }
                                  )
                                : const Icon(Icons.search, size: 20, color: Colors.grey),
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
            Text('Order Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // ── Items ───────────────────────────────────────────────────────
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final line = _lines[index];
                return RepaintBoundary(
                  child: _SaleItemRow(
                    key: ValueKey('row_${index}_${line.hashCode}'),
                    index: index,
                    line: line,
                    availableStock: availableStock,
                    usedStockKeys: usedStockKeys,
                    onRemove: () => _removeLine(index),
                    onChanged: () => setState(() {}),
                    onSelected: (row) async {
                      setState(() { 
                        line.stockRow = row; 
                        line.quantity = 1; 
                        line.qtyController.text = '1'; 
                      });
                      final activeShop = ref.read(activeShopProvider);
                      if (activeShop != null && _selectedParty != null) {
                        final rate = await ref.read(salesRepositoryProvider).getPartyProductRate(activeShop.id, _selectedParty!.id, line.productHeadId);
                        if (mounted) setState(() => line.rateController.text = (rate ?? line.rate).toString());
                      } else {
                        setState(() => line.rateController.text = line.rate.toString());
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Add Item Button ─────────────────────────────────────────────
            Center(
              child: TextButton.icon(
                onPressed: _addLine,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppColors.primary.withAlpha(50)),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Another Item', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),

            // ── Grand Total + Save ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Sheets', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        '${_lines.where((l) => l.stockRow != null).fold<int>(0, (sum, l) => sum + l.quantity)}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_editingInvoiceNo != null)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _cancelEdit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      
                      ElevatedButton(
                        onPressed: _isSaving ? null : () => _saveChallan(print: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                        ),
                        child: _isSaving 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                          : Text(_editingInvoiceNo != null ? 'Update Only' : 'Save Only', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _saveChallan(print: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 4,
                          shadowColor: AppColors.primary.withOpacity(0.4),
                        ),
                        icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.print_rounded, size: 18),
                        label: Text(_editingInvoiceNo != null ? 'Update & Print' : 'Save & Print', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
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
                Text('Recent Sales', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            recentSalesAsync.when(
              data: (groupedSales) {
                if (groupedSales.isEmpty) {
                  return const EmptyStateView(
                    title: 'No sales yet',
                    message: 'Sales challans will appear here.',
                    icon: Icons.receipt_long_outlined,
                  );
                }

                final listView = RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.refresh(groupedRecentSalesProvider.future),
                  child: ListView.separated(
                  shrinkWrap: !isWide, 
                  physics: isWide ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
                  itemCount: groupedSales.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final invoiceNo = groupedSales.keys.elementAt(index);
                    final entries = groupedSales[invoiceNo]!;
                    final firstEntry = entries.first;
                    final totalSheets = entries.fold<int>(0, (sum, item) => sum + item.quantity);
                    final isSelected = invoiceNo == _editingInvoiceNo;

                    return ListTile(
                      dense: true,
                      tileColor: isSelected ? Colors.blue.shade50.withOpacity(0.5) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: isSelected ? Colors.blue.shade100 : AppColors.primary.withAlpha(15),
                        child: Icon(Icons.receipt, size: 20, color: isSelected ? Colors.blue.shade700 : AppColors.primary),
                      ),
                      title: Text(invoiceNo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Colors.blue.shade900 : AppColors.textPrimary)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(firstEntry.partyName ?? 'Unknown Party', style: TextStyle(fontSize: 12, color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700, fontWeight: FontWeight.w500)),
                          Text('${firstEntry.date.toString().substring(0, 10)}  •  $totalSheets Sheets', style: TextStyle(fontSize: 11, color: isSelected ? Colors.blue.shade400 : Colors.grey.shade500)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              tooltip: 'Cancel Edit',
                              onPressed: _cancelEdit,
                            ),
                          IconButton(
                            icon: Icon(isSelected ? Icons.edit : Icons.edit_document, size: 20, color: isSelected ? Colors.blue : Colors.blueGrey),
                            onPressed: isSelected ? null : () {
                               partiesAsync.whenData((parties) {
                                  stockAsync.whenData((stock) {
                                      _loadInvoiceForEdit(invoiceNo, entries, parties, stock);
                                  });
                               });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.print, size: 20, color: AppColors.primary),
                            onPressed: () async {
                               try {
                                 final activeShop = ref.read(activeShopProvider);
                                 if (activeShop == null) {
                                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop data not loaded')));
                                   return;
                                 }

                                 // Get data from providers. If still loading, wait or show message.
                                 final parties = partiesAsync.value;
                                 final stock = stockAsync.value;

                                 if (parties == null || stock == null) {
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data still loading, please wait...')));
                                    return;
                                 }

                                 // Safe lookup for party
                                 final party = parties.where((p) => p.id == firstEntry.partyId).firstOrNull ?? 
                                              Party(
                                                id: firstEntry.partyId, 
                                                partyName: firstEntry.partyName ?? 'Unknown',
                                                timeAdded: DateTime.now(),
                                                shopId: firstEntry.shopId,
                                              );

                                 final challanLines = entries.map((e) {
                                    // 1. Try metadata directly from the entry (fetched via joins in repository)
                                    // 2. Fallback to searching stock cache if joins are missing/legacy
                                    // 3. Absolute fallback to IDs
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
                                        // Still empty? Force format IDs
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
                                 );
                               } catch (e) {
                                 if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text('Print Error: $e'), backgroundColor: Colors.red),
                                   );
                                 }
                               }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
                return isWide ? Expanded(child: listView) : listView;
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())),
              error: (err, stack) => ErrorView(
                error: err,
                onRetry: () => ref.invalidate(groupedRecentSalesProvider),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: _editingInvoiceNo != null ? const Color(0xFFF1F5F9) : AppColors.scaffoldBg, // Light slate in edit mode
      resizeToAvoidBottomInset: false,
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
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: SingleChildScrollView(child: formContent)),
                        Expanded(flex: 2, child: recentSalesContent), // Removed outer SingleChildScrollView for Desktop performance
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
            ),
          ),
          if (_isSaving)
            const LoadingOverlay(message: 'Saving Invoice...'),
        ],
      ),
    );
  }
}

// ─── Optimized Sub-Widget for Sales Row ───────────────────────────────────────
class _SaleItemRow extends StatefulWidget {
  final int index;
  final _SaleItemLine line;
  final List<Map<String, dynamic>> availableStock;
  final Set<String> usedStockKeys;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final Function(Map<String, dynamic>) onSelected;

  const _SaleItemRow({
    super.key,
    required this.index,
    required this.line,
    required this.availableStock,
    required this.usedStockKeys,
    required this.onRemove,
    required this.onChanged,
    required this.onSelected,
  });

  @override
  State<_SaleItemRow> createState() => _SaleItemRowState();
}

class _SaleItemRowState extends State<_SaleItemRow> {
  // ── Robust Data Extraction Helper ──
  Map<String, dynamic>? _getData(dynamic d) {
    if (d == null) return null;
    if (d is List) return d.isEmpty ? null : d.first as Map<String, dynamic>;
    if (d is Map) return d as Map<String, dynamic>;
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withAlpha(12), shape: BoxShape.circle),
            child: Text('${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<Map<String, dynamic>>(
                    initialValue: widget.line.stockRow != null
                        ? TextEditingValue(text: '${widget.line.designNo}  |  ${widget.line.locationName}  |  ${widget.line.maxQuantity}')
                        : TextEditingValue.empty,
                    displayStringForOption: (row) {
                      final d = (row['products_design']?['design_no'] as String?) ?? '';
                      final l = (row['locations']?['name'] as String?) ?? '';
                      final q = (row['quantity'] as int?) ?? 0;
                      return '$d  |  $l  |  $q';
                    },
                    optionsBuilder: (tv) {
                      final q = tv.text.toLowerCase();
                      
                      // ── If query is empty, show top 50 available items ──
                      if (q.isEmpty) {
                        return widget.availableStock.where((r) {
                          final pd = _getData(r['products_design']);
                          final loc = _getData(r['locations']);
                          final dId = (pd?['id'] as int?) ?? 0;
                          final lId = (loc?['id'] as int?) ?? 0;
                          return !widget.usedStockKeys.contains('${dId}_${lId}');
                        }).take(50);
                      }
                      
                      return widget.availableStock.where((r) {
                        final pd = _getData(r['products_design']);
                        final loc = _getData(r['locations']);
                        
                        final dId = (pd?['id'] as int?) ?? 0;
                        final lId = (loc?['id'] as int?) ?? 0;
                        final key = '${dId}_${lId}';
                        
                        // Exclusion logic
                        if (widget.line.stockRow != null && widget.line.designId == dId && widget.line.locationId == lId) {
                           // Allowed
                        } else if (widget.usedStockKeys.contains(key)) {
                          return false;
                        }

                        // Fast search logic using pre-calculated key (Fallback to design_no if key missing)
                        final searchKey = r['search_key'] as String?;
                        if (searchKey != null) return searchKey.contains(q);
                        
                        final dNo = (pd?['design_no'] as String? ?? '').toLowerCase();
                        final lName = (loc?['name'] as String? ?? '').toLowerCase();
                        return dNo.contains(q) || lName.contains(q);
                      });
                    },
                    onSelected: widget.onSelected,
                    optionsViewBuilder: (context, onSel, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 10,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 350, maxWidth: 500),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  color: AppColors.primary.withAlpha(20),
                                  child: const Row(
                                    children: [
                                      Expanded(flex: 3, child: Text('Design No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
                                      Expanded(flex: 2, child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
                                      SizedBox(width: 50, child: Text('Stock', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, idx) {
                                      final row = options.elementAt(idx);
                                      final pd = _getData(row['products_design']);
                                      final loc = _getData(row['locations']);
                                      
                                      final dNo = (pd?['design_no'] as String?) ?? '';
                                      final lName = (loc?['name'] as String?) ?? '';
                                      final qty = (row['quantity'] as int?) ?? 0;

                                      return InkWell(
                                        onTap: () => onSel(row),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 3, child: Text(dNo, style: const TextStyle(fontWeight: FontWeight.w600))),
                                              Expanded(flex: 2, child: Text(lName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                                              SizedBox(
                                                width: 50, 
                                                child: Text('$qty', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: qty < 5 ? Colors.red : Colors.green))
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
                    fieldViewBuilder: (context, ctrl, focusNode, onSub) {
                      return Consumer(builder: (context, ref, _) {
                        final stockStatus = ref.watch(shopStockProvider);
                        final isLoading = stockStatus.isLoading;
                        final isError = stockStatus.hasError;

                        return TextFormField(
                          controller: ctrl,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: isLoading 
                                ? 'Fetching stock items...' 
                                : (isError ? 'Error loading stock' : 'Search Design Numbers'),
                            hintText: 'Type to filter...',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                            filled: true,
                            fillColor: (isLoading || isError) ? Colors.grey.shade50 : Colors.white,
                            prefixIcon: isLoading 
                                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                : Icon(isError ? Icons.error_outline : Icons.manage_search_rounded, color: isError ? Colors.red : AppColors.accent),
                            suffixIcon: widget.line.stockRow != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () { 
                                      ctrl.clear(); 
                                      widget.onSelected({}); 
                                      setState(() { widget.line.stockRow = null; });
                                    },
                                  )
                                : null,
                          ),
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: widget.line.qtyController,
                    enabled: widget.line.stockRow != null,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      helperText: widget.line.stockRow != null ? 'Max: ${widget.line.maxQuantity}' : null,
                      helperStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      int q = int.tryParse(v) ?? 1;
                      if (q > widget.line.maxQuantity) q = widget.line.maxQuantity;
                      widget.line.quantity = q > 0 ? q : 1;
                      if (q.toString() != v) {
                        widget.line.qtyController.text = widget.line.quantity.toString();
                        widget.line.qtyController.selection = TextSelection.fromPosition(TextPosition(offset: widget.line.qtyController.text.length));
                      }
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: widget.line.rateController,
                    enabled: widget.line.stockRow != null,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Rate',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => widget.onChanged(),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}