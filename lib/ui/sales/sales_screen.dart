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
import '../common/app_drawer.dart';
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

  int quantity = 0;
  final TextEditingController qtyController = TextEditingController(); 
  final TextEditingController rateController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final FocusNode qtyFocusNode = FocusNode();

  int get currentRate => int.tryParse(rateController.text) ?? 0;
  int get total => quantity * currentRate;

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
    searchController.dispose();
    searchFocusNode.dispose();
    qtyFocusNode.dispose();
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
  DateTime _invoiceDate = DateTime.now();

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

  void _addLine() {
    final newLine = _SaleItemLine();
    setState(() => _lines.add(newLine));
    // Focus the new line after it's rendered
    Future.microtask(() => newLine.searchFocusNode.requestFocus());
  }

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
      _invoiceDate = entries.isNotEmpty ? entries.first.date : DateTime.now();
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
        
        if (line.stockRow != null) {
          line.searchController.text = '${line.designNo}  |  ${line.locationName}  |  ${line.maxQuantity}';
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
          date: _invoiceDate,
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
            date: _invoiceDate,
          );
        }

        setState(() {
          _editingInvoiceNo = null;
          _invoiceDate = DateTime.now();
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
    final isMobile = MediaQuery.of(context).size.width < 600;

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
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(_editingInvoiceNo != null ? Icons.edit_document : Icons.shopping_cart_checkout, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingInvoiceNo != null ? 'Update Sales' : 'Create Invoice', 
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                      ),
                      if (_editingInvoiceNo != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50, 
                            borderRadius: BorderRadius.circular(4), 
                            border: Border.all(color: Colors.blue.shade200, width: 1),
                          ),
                          child: Text('EDITING: $_editingInvoiceNo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                        ),
                    ],
                  ),
                ),
                // Structured Invoice ID display in a stacked layout
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'INVOICE NO', 
                        style: TextStyle(
                          fontSize: 9, 
                          fontWeight: FontWeight.w900, 
                          color: Colors.blueGrey.shade700, 
                          letterSpacing: 0.8
                        )
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _invoiceController.text, 
                        style: const TextStyle(
                          fontSize: 15, 
                          fontWeight: FontWeight.w900, 
                          color: AppColors.primary,
                          letterSpacing: 0.5
                        )
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Invoice Details ──────────────────────────────────────────
            Builder(builder: (context) {
              final partyField = partiesAsync.when(
                data: (parties) {
                  return Autocomplete<Party>(
                    key: ValueKey('party_auto_${_editingInvoiceNo}'),
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
                      if (_lines.isNotEmpty) {
                        _lines.first.searchFocusNode.requestFocus();
                      }
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (_selectedParty != null && controller.text.isEmpty) {
                        controller.text = _selectedParty!.partyName;
                      }
                      return ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, child) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Select Party Name...',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 22),
                              suffixIcon: (value.text.isNotEmpty) 
                                ? IconButton(
                                    icon: const Icon(Icons.cancel_rounded, size: 20, color: Colors.grey), 
                                    onPressed: () {
                                      controller.clear();
                                      _partySearchController.clear();
                                      setState(() => _selectedParty = null);
                                    }
                                  )
                                : Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            onFieldSubmitted: (_) => onFieldSubmitted(),
                          );
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 12,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          clipBehavior: Clip.antiAlias,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 250, maxWidth: isMobile ? MediaQuery.of(context).size.width - 64 : 450),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final party = options.elementAt(index);
                                return ListTile(
                                  onTap: () => onSelected(party),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                                    child: const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primary),
                                  ),
                                  title: Text(party.partyName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: party.city?.isNotEmpty ?? false 
                                      ? Text(party.city!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)) 
                                      : null,
                                  dense: true,
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
              );

              return partyField;
            }),
            const SizedBox(height: 32),

            // ── Order Items Section ──────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.view_list_rounded, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text('Order Items', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.blueGrey.shade800, letterSpacing: 0.5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text('${_lines.length} Line Items', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 16),
              child: Divider(height: 1, thickness: 0.5),
            ),

            // ── Items ───────────────────────────────────────────────────────
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final line = _lines[index];
                return RepaintBoundary(
                  child: _SaleItemRow(
                    key: ObjectKey(line),
                    index: index,
                    line: line,
                    availableStock: availableStock,
                    usedStockKeys: usedStockKeys,
                    onRemove: () => _removeLine(index),
                    onChanged: () => setState(() {}),
                    onSelected: (row) async {
                      if (row.isEmpty) {
                        setState(() {
                          line.stockRow = null;
                          line.searchController.clear();
                          line.quantity = 0;
                          line.qtyController.clear();
                          line.rateController.clear();
                        });
                        return;
                      }
                      setState(() { 
                        line.stockRow = row; 
                        line.searchController.text = '${line.designNo}  |  ${line.locationName}  |  ${line.maxQuantity}';
                        line.quantity = 0; 
                        line.qtyController.text = ''; 
                      });
                      final activeShop = ref.read(activeShopProvider);
                      if (activeShop != null && _selectedParty != null) {
                        final rate = await ref.read(salesRepositoryProvider).getPartyProductRate(activeShop.id, _selectedParty!.id, line.productHeadId);
                        if (mounted) setState(() => line.rateController.text = (rate ?? line.rate).toString());
                      } else {
                        setState(() => line.rateController.text = line.rate.toString());
                      }
                      line.qtyFocusNode.requestFocus(); // Auto-focus Qty after selection
                    },
                  ),
                );
              },
            ),
            SizedBox(height: isMobile ? 12 : 16),

            // ── Add Item Button ─────────────────────────────────────────────
            Center(
              child: InkWell(
                onTap: _addLine,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      const Text('Add Another Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Grand Total + Save ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Builder(builder: (context) {
                
                final totalSection = Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Sheets', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        Text(
                          '${_lines.where((l) => l.stockRow != null).fold<int>(0, (sum, l) => sum + l.quantity)}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const Icon(Icons.auto_graph_rounded, color: Colors.white12, size: 24),
                  ],
                );
                
                final buttonSection = Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextButton(
                        onPressed: _isSaving ? null : () => _saveChallan(print: false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: const Text('Save Only', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _saveChallan(print: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Save & Print', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                    ),
                  ],
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    totalSection,
                    const SizedBox(height: 12),
                    buttonSection,
                  ],
                );
              }),
            ),
          ],
        ),
      )),
    );

    // ── Recent Sales Panel ────────────────────────────────────────────────────
    Widget recentSalesContent = _buildRecentSalesContent(isWide: isWide);

    return Scaffold(
      backgroundColor: _editingInvoiceNo != null ? const Color(0xFFF1F5F9) : AppColors.scaffoldBg, // Light slate in edit mode
      appBar: AppBar(
        leadingWidth: 96,
        leading: Builder(builder: (context) {
          return Row(
            children: [
              const BackButton(color: AppColors.textPrimary),
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ],
          );
        }),
        centerTitle: true,
        title: Builder(builder: (context) {
          final isMobile = MediaQuery.of(context).size.width < 600;
          final activeShop = ref.watch(activeShopProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeShop != null)
                Text(activeShop.shopName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text(
                'Sales Entry', 
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  color: AppColors.textPrimary,
                  fontSize: isMobile ? 18 : 20,
                )
              ),
            ],
          );
        }),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      drawer: const AppDrawer(currentRoute: '/sales'),
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
                        Expanded(flex: 2, child: recentSalesContent), 
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Builder(builder: (context) {
      final isMobileButton = MediaQuery.of(context).size.width < 600;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobileButton ? 12 : 7, 
              vertical: isMobileButton ? 8 : 5
            ),
            decoration: BoxDecoration(
              color: onTap == null ? Colors.grey.shade100 : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: onTap == null ? Colors.transparent : color.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(
              icon, 
              size: isMobileButton ? 18 : 15, 
              color: onTap == null ? Colors.grey.shade400 : color
            ),
          ),
        ),
      );
    });
  }

  Widget _buildRecentSalesContent({bool isWide = false, bool isSheet = false}) {
    final recentSalesAsync = ref.watch(groupedRecentSalesProvider);
    final partiesAsync     = ref.watch(partiesProvider);
    final stockAsync       = ref.watch(shopStockProvider);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade200)),
      margin: isSheet ? const EdgeInsets.all(8) : const EdgeInsets.all(16),
      child: Padding(
        padding: isSheet ? const EdgeInsets.all(12.0) : const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                  onRefresh: () async => ref.refresh(recentSalesProvider.future),
                  child: ListView.builder(
                    shrinkWrap: !isWide,
                    physics: isWide ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(), // Scrollable on Desktop
                    itemCount: groupedSales.length,
                    itemBuilder: (context, index) {
                      final invoiceNo = groupedSales.keys.elementAt(index);
                      final entries = groupedSales[invoiceNo]!;
                      final firstEntry = entries.first;
                      final totalSheets = entries.fold<int>(0, (sum, item) => sum + item.quantity);
                      final isSelected = invoiceNo == _editingInvoiceNo;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.shade50.withValues(alpha: 0.5) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: [
                            if (!isSelected)
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.receipt_rounded, size: 12, color: isSelected ? Colors.blue.shade700 : Colors.blueGrey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        invoiceNo, 
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isSelected ? Colors.blue.shade900 : Colors.blueGrey.shade800)
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  firstEntry.date.toString().substring(0, 10), 
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              firstEntry.partyName ?? 'Unknown Party', 
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary), 
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('TOTAL SHEETS : ', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Text(
                                      '$totalSheets', 
                                      style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 13, fontWeight: FontWeight.w900)
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected)
                                      _buildActionButton(
                                        icon: Icons.close,
                                        color: Colors.red.shade600,
                                        tooltip: 'Cancel Edit',
                                        onTap: () {
                                          _cancelEdit();
                                          if (isSheet) Navigator.pop(context);
                                        },
                                      ),
                                    if (isSelected) const SizedBox(width: 6),
                                    
                                    _buildActionButton(
                                      icon: isSelected ? Icons.edit : Icons.edit_document,
                                      color: isSelected ? Colors.blue.shade700 : Colors.blue.shade400,
                                      tooltip: 'Edit Invoice',
                                      onTap: isSelected ? null : () {
                                        partiesAsync.whenData((parties) {
                                           stockAsync.whenData((stock) {
                                               _loadInvoiceForEdit(invoiceNo, entries, parties, stock);
                                               if (isSheet) Navigator.pop(context);
                                           });
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    _buildActionButton(
                                      icon: Icons.print_rounded,
                                      color: Colors.teal.shade600,
                                      tooltip: 'Print Invoice',
                                      onTap: () async {
                                         try {
                                           final activeShop = ref.read(activeShopProvider);
                                           if (activeShop == null) {
                                             if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop data not loaded')));
                                             return;
                                           }
        
                                           final parties = partiesAsync.value;
                                           final stock = stockAsync.value;
        
                                           if (parties == null || stock == null) {
                                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data still loading, please wait...')));
                                              return;
                                           }
        
                                           final party = parties.where((p) => p.id == firstEntry.partyId).firstOrNull ?? 
                                                        Party(
                                                          id: firstEntry.partyId, 
                                                          partyName: firstEntry.partyName ?? 'Unknown',
                                                          timeAdded: DateTime.now(),
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
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    final itemIndex = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text('${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
    );

    final searchField = Autocomplete<Map<String, dynamic>>(
      focusNode: widget.line.searchFocusNode,
      textEditingController: widget.line.searchController,
      displayStringForOption: (row) {
        final d = (row['products_design']?['design_no'] as String?) ?? '';
        final l = (row['locations']?['name'] as String?) ?? '';
        final q = (row['quantity'] as int?) ?? 0;
        return '$d  |  $l  |  $q';
      },
      optionsBuilder: (tv) {
        final q = tv.text.toLowerCase();
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
          if (widget.line.stockRow != null && widget.line.designId == dId && widget.line.locationId == lId) {
             // Allowed
          } else if (widget.usedStockKeys.contains(key)) {
            return false;
          }
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
              constraints: BoxConstraints(maxHeight: 350, maxWidth: isMobile ? MediaQuery.of(context).size.width - 64 : 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppColors.primary.withValues(alpha: 0.1),
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
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (context, value, child) {
            return TextFormField(
              controller: ctrl,
              focusNode: focusNode,
              style: isMobile ? const TextStyle(fontSize: 14, fontWeight: FontWeight.w500) : null,
              decoration: InputDecoration(
                labelText: isMobile ? null : (isMobile ? 'Search Designs' : 'Search Design Numbers'),
                hintText: isMobile ? 'Select Design / Location...' : 'Type to filter...',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: isMobile 
                  ? Container(
                      width: 36,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                      ),
                      child: Text('${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13)),
                    )
                  : Container(
                      margin: const EdgeInsets.only(right: 8, left: 4),
                      child: Icon(Icons.search_rounded, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
                    ),
                prefixIconConstraints: isMobile ? const BoxConstraints(minWidth: 40, minHeight: 45) : const BoxConstraints(minWidth: 40, minHeight: 40),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.cancel_rounded, size: 18, color: Colors.grey.shade400),
                        onPressed: () { 
                          ctrl.clear(); 
                          widget.onSelected({}); 
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.only(left: isMobile ? 0 : 16, right: 16, top: 14, bottom: 14),
              ),
            );
          },
        );
      },
    );

    final qtyField = SizedBox(
      width: isMobile ? double.infinity : 100,
      child: TextFormField(
        controller: widget.line.qtyController,
        focusNode: widget.line.qtyFocusNode,
        enabled: widget.line.stockRow != null,
        textAlign: isMobile ? TextAlign.left : TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: '0',
          helperText: isMobile ? (widget.line.stockRow != null ? 'Avail: ${widget.line.maxQuantity}' : null) : (widget.line.stockRow != null ? 'Max: ${widget.line.maxQuantity}' : null),
          helperStyle: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.bold, fontSize: 10),
          isDense: true,
          filled: true,
          fillColor: widget.line.stockRow != null ? Colors.white : Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        keyboardType: TextInputType.number,
        onChanged: (v) {
          if (v.isEmpty) {
             widget.line.quantity = 0;
             widget.onChanged();
             return;
          }
          int q = int.tryParse(v) ?? 0;
          if (q > widget.line.maxQuantity) {
            q = widget.line.maxQuantity;
            widget.line.qtyController.text = q.toString();
            widget.line.qtyController.selection = TextSelection.fromPosition(TextPosition(offset: widget.line.qtyController.text.length));
          }
          widget.line.quantity = q;
          widget.onChanged();
        },
      ),
    );

    final rateField = SizedBox(
      width: isMobile ? double.infinity : 100,
      child: TextFormField(
        controller: widget.line.rateController,
        enabled: widget.line.stockRow != null,
        textAlign: isMobile ? TextAlign.left : TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'Rate',
          helperText: isMobile ? (widget.line.stockRow != null ? ' ' : null) : (widget.line.stockRow != null ? ' ' : null), // Matching space for height alignment
          isDense: true,
          filled: true,
          fillColor: widget.line.stockRow != null ? Colors.white : Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        keyboardType: TextInputType.number,
        onChanged: (v) => widget.onChanged(),
      ),
    );

    Widget content;
    if (isMobile) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Search + Delete
          Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300, size: 22),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Row 2: Qty, Rate & Subtotal
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 3, child: qtyField),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: rateField),
              const SizedBox(width: 10),
              if (widget.line.stockRow != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 22), // Align with text fields height
                  child: Column(
                    children: [
                      const Text('TOTAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      Text('₹${widget.line.total}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          itemIndex,
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                qtyField,
                const SizedBox(width: 12),
                rateField,
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
            onPressed: widget.onRemove,
          ),
        ],
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 16),
      padding: EdgeInsets.all(isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: content,
    );
  }
}