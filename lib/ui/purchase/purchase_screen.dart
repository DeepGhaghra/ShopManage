import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import '../../services/purchase_providers.dart';
import '../../services/party_providers.dart';
import '../../services/stock_providers.dart';
import '../../models/party.dart';
import '../../services/core_providers.dart';
import '../../theme/app_theme.dart';

// ─── Local line model for Manual Entry tab ─────────────────────────────────────
class _ManualLine {
  Map<String, dynamic>? designMap; // from designsProvider
  int? locationId;
  String locationName = '';
  int quantity = 1;

  String get designNo => (designMap?['design_no'] as String?) ?? '';
  int get designId    => (designMap?['id']        as int?)    ?? 0;
  bool get isValid    => designMap != null && locationId != null && quantity > 0;
}

// ─── Parsed row for Bulk Upload tab ──────────────────────────────────────────
class _BulkRow {
  final String rawDesignNo;
  final String rawLocation;
  final int rawQty;

  // resolved after matching against DB
  int?    designId;
  int?    locationId;
  String? errorMsg;

  _BulkRow({required this.rawDesignNo, required this.rawLocation, required this.rawQty});

  bool get isValid => designId != null && locationId != null && rawQty > 0 && errorMsg == null;
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tabController;
  Party?    _selectedParty;
  DateTime  _selectedDate = DateTime.now();
  bool      _isSaving     = false;
  int       _formResetKey = 0;

  // Manual tab
  final List<_ManualLine> _manualLines = [_ManualLine()];

  // Bulk tab
  String?         _uploadedFileName;
  List<_BulkRow>  _bulkRows = [];
  bool            _isParsing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Date picker ──────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Manual tab helpers ───────────────────────────────────────────────────────
  void _addManualLine() => setState(() => _manualLines.add(_ManualLine()));
  void _removeManualLine(int i) {
    setState(() {
      _manualLines.removeAt(i);
      if (_manualLines.isEmpty) _manualLines.add(_ManualLine());
    });
  }

  // ── Bulk upload ──────────────────────────────────────────────────────────────
  Future<void> _pickExcelFile(List<Map<String, dynamic>> designs, List<Map<String, dynamic>> locations) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() { _isParsing = true; _bulkRows = []; _uploadedFileName = null; });

    try {
      final bytes  = result.files.single.bytes!;
      final excel  = xl.Excel.decodeBytes(bytes);
      final sheet  = excel.tables.values.first;
      final rows   = sheet.rows;

      if (rows.isEmpty) { _showError('Excel file is empty.'); return; }

      // Find header row — look for "Design No", "Location", "Qty"
      int headerIdx = -1;
      int colDesign = -1, colLocation = -1, colQty = -1;
      for (int r = 0; r < rows.length && r < 5; r++) {
        final cells = rows[r].map((c) => c?.value?.toString().trim().toLowerCase() ?? '').toList();
        final di = cells.indexWhere((c) => c.contains('design'));
        final li = cells.indexWhere((c) => c.contains('location') || c.contains('loc'));
        final qi = cells.indexWhere((c) => c.contains('qty') || c.contains('quantity'));
        if (di != -1 && li != -1 && qi != -1) {
          headerIdx = r; colDesign = di; colLocation = li; colQty = qi;
          break;
        }
      }

      if (headerIdx == -1) {
        _showError('Could not find header row.\nExpected columns: "Design No", "Location", "Qty"');
        return;
      }

      // Build lookup maps
      final designMap   = { for (var d in designs)    (d['design_no'] as String).toLowerCase() : d };
      final locationMap = { for (var l in locations)  (l['name']      as String).toLowerCase() : l };

      final parsed = <_BulkRow>[];
      for (int r = headerIdx + 1; r < rows.length; r++) {
        final row      = rows[r];
        final rawDesign  = row[colDesign]?.value?.toString().trim()  ?? '';
        final rawLoc     = row[colLocation]?.value?.toString().trim() ?? '';
        final rawQtyStr  = row[colQty]?.value?.toString().trim()     ?? '';
        if (rawDesign.isEmpty && rawLoc.isEmpty) continue; // skip empty rows

        final qty = int.tryParse(rawQtyStr) ?? 0;
        final bulkRow = _BulkRow(rawDesignNo: rawDesign, rawLocation: rawLoc, rawQty: qty);

        final dMatch = designMap[rawDesign.toLowerCase()];
        final lMatch = locationMap[rawLoc.toLowerCase()];

        if (dMatch == null) {
          bulkRow.errorMsg = 'Design "$rawDesign" not found';
        } else if (lMatch == null) {
          bulkRow.errorMsg = 'Location "$rawLoc" not found';
        } else if (qty <= 0) {
          bulkRow.errorMsg = 'Qty must be > 0';
        } else {
          bulkRow.designId   = dMatch['id']  as int;
          bulkRow.locationId = lMatch['id']  as int;
        }

        parsed.add(bulkRow);
      }

      setState(() {
        _bulkRows        = parsed;
        _uploadedFileName = result.files.single.name;
      });
    } catch (e) {
      _showError('Failed to parse Excel: $e');
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  /// Generate and download a blank template Excel
  Future<void> _downloadTemplate() async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Sheet1'];
    // Header
    sheet.appendRow([xl.TextCellValue('Design No'), xl.TextCellValue('Location'), xl.TextCellValue('Qty')]);

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Purchase Template',
        fileName: 'Purchase_Template.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(fileBytes),
      );

      if (outputFile != null) {
        final file = File(outputFile);
        if (!await file.exists()) {
           await file.writeAsBytes(fileBytes);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Template saved: $outputFile'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      if (mounted) _showError('Could not save template: $e');
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final activeShop = ref.read(activeShopProvider);
    if (activeShop == null || _selectedParty == null) {
      _showError('Please select a party first.');
      return;
    }

    final isManual = _tabController.index == 0;
    List<PurchaseLine> lines;

    if (isManual) {
      final invalid = _manualLines.any((l) => !l.isValid);
      if (invalid) { _showError('Fill all fields in every row.'); return; }
      lines = _manualLines.map((l) => PurchaseLine(
        designNo:   l.designNo,
        designId:   l.designId,
        locationId: l.locationId!,
        quantity:   l.quantity,
      )).toList();
    } else {
      final invalid = _bulkRows.any((r) => !r.isValid);
      if (invalid) { 
        _showError('Cannot save: Excel file contains errors. Please fix all 🔴 errors first an reupload again'); 
        return; 
      }
      if (_bulkRows.isEmpty) { 
        _showError('No rows to save.'); 
        return; 
      }
      lines = _bulkRows.map((r) => PurchaseLine(
        designNo:   r.rawDesignNo,
        designId:   r.designId!,
        locationId: r.locationId!,
        quantity:   r.rawQty,
      )).toList();
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(purchaseRepositoryProvider).saveBulkPurchase(
        shopId:  activeShop.id,
        partyId: _selectedParty!.id,
        date:    DateFormat('yyyy-MM-dd').format(_selectedDate),
        lines:   lines,
      );

      // Refresh stock list
      ref.invalidate(shopStockProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${lines.length} purchase entries saved!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        // Reset
        setState(() {
          _selectedParty = null;
          _selectedDate  = DateTime.now();
          _manualLines.clear(); _manualLines.add(_ManualLine());
          _bulkRows = []; _uploadedFileName = null;
          _formResetKey++;
        });
      }
    } catch (e) {
      if (mounted) _showError('Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final partiesAsync   = ref.watch(partiesProvider);
    final designsAsync   = ref.watch(designsProvider);
    final locationsAsync = ref.watch(locationsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Purchase Entry', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            if (ref.watch(activeShopProvider) != null)
              Row(children: [
                const Icon(Icons.storefront_rounded, size: 13, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(ref.watch(activeShopProvider)!.shopName,
                    style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ]),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual Entry'),
            Tab(icon: Icon(Icons.upload_file_rounded), text: 'Bulk Upload'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // ── Shared header: Party + Date ──────────────────────────────────────
              KeyedSubtree(
                key: ValueKey('header_$_formResetKey'),
                child: _buildHeader(partiesAsync),
              ),

              // ── Tab views ────────────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  key: ValueKey('tabs_$_formResetKey'),
                  controller: _tabController,
                  children: [
                    // Tab 1 — Manual Entry
                    designsAsync.when(
                      data: (designs) {
                        final sortedDesigns = List<Map<String, dynamic>>.from(designs)
                          ..sort((a, b) => (a['design_no'] as String).toUpperCase().compareTo((b['design_no'] as String).toUpperCase()));
                        return locationsAsync.when(
                          data: (locations) => _buildManualTab(sortedDesigns, locations),
                          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                          error: (e, _) => Center(child: Text('Error: $e')),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                    // Tab 2 — Bulk Upload
                    designsAsync.when(
                      data: (designs) => locationsAsync.when(
                        data: (locations) => _buildBulkTab(designs, locations),
                        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        error: (e, _) => Center(child: Text('Error: $e')),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(AsyncValue<List<Party>> partiesAsync) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
          // Party autocomplete
          Expanded(
            flex: 3,
            child: partiesAsync.when(
              data: (parties) => Autocomplete<Party>(
                initialValue: TextEditingValue(text: _selectedParty?.partyName ?? ''),
                displayStringForOption: (p) => p.partyName,
                optionsBuilder: (tv) {
                  if (tv.text.isEmpty) return parties;
                  return parties.where((p) => p.partyName.toLowerCase().contains(tv.text.toLowerCase()));
                },
                onSelected: (p) => setState(() => _selectedParty = p),
                fieldViewBuilder: (ctx, ctrl, fn, sub) => TextFormField(
                  controller: ctrl, focusNode: fn,
                  decoration: InputDecoration(
                    labelText: 'Search Party',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    filled: true, fillColor: AppColors.scaffoldBg,
                    prefixIcon: const Icon(Icons.business, size: 18, color: AppColors.accent),
                  ),
                  onFieldSubmitted: (_) => sub(),
                ),
                optionsViewBuilder: (ctx, onSel, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8, borderRadius: BorderRadius.circular(12), color: Colors.white,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                      child: ListView.builder(
                        padding: EdgeInsets.zero, shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, i) {
                          final p = options.elementAt(i);
                          return ListTile(dense: true,
                            leading: const Icon(Icons.business, size: 16, color: AppColors.accent),
                            title: Text(p.partyName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: p.city != null ? Text(p.city!, style: const TextStyle(fontSize: 11)) : null,
                            onTap: () => onSel(p),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ),
          const SizedBox(width: 12),
          // Date picker
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),
);
}

// ── Tab 1: Manual Entry ───────────────────────────────────────────────────────
Widget _buildManualTab(List<Map<String, dynamic>> designs, List<Map<String, dynamic>> locations) {
  final validCount = _manualLines.where((l) => l.isValid).length;

    return Column(
      children: [
        // Column headers
        Container(
          color: AppColors.primary.withAlpha(10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              Expanded(flex: 4, child: Text('Design No', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent))),
              SizedBox(width: 8),
              Expanded(flex: 3, child: Text('Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent))),
              SizedBox(width: 8),
              SizedBox(width: 72, child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent))),
              SizedBox(width: 40),
            ],
          ),
        ),

        // Rows
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _manualLines.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              if (index == _manualLines.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: _addManualLine,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Another Row', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: AppColors.primary.withAlpha(25),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                );
              }
              return _buildManualRow(index, designs, locations);
            },
          ),
        ),

        // Save
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _isSaving || validCount == 0 ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving…' : 'Save Purchase ($validCount)'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualRow(int index, List<Map<String, dynamic>> designs, List<Map<String, dynamic>> locations) {
    final line = _manualLines[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Design autocomplete
          Expanded(
            flex: 4,
            child: Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(text: line.designNo),
              displayStringForOption: (d) => d['design_no'] as String,
              optionsBuilder: (tv) {
                if (tv.text.isEmpty) return designs;
                return designs.where((d) =>
                    (d['design_no'] as String).toLowerCase().contains(tv.text.toLowerCase()));
              },
              onSelected: (d) => setState(() { line.designMap = d; }),
              fieldViewBuilder: (ctx, ctrl, fn, sub) => TextFormField(
                controller: ctrl, focusNode: fn,
                decoration: InputDecoration(
                  hintText: 'Design No',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  filled: true, fillColor: Colors.white,
                ),
                onFieldSubmitted: (_) => sub(),
              ),
              optionsViewBuilder: (ctx, onSel, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8, borderRadius: BorderRadius.circular(10), color: Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 260),
                    child: ListView.builder(
                      padding: EdgeInsets.zero, shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final d = options.elementAt(i);
                        return ListTile(
                          dense: true,
                          title: Text(d['design_no'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text((d['product_head']?['product_name'] ?? '') as String, style: const TextStyle(fontSize: 11)),
                          onTap: () => onSel(d),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Location dropdown
          // Location autocomplete
          Expanded(
            flex: 3,
            child: Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(text: line.locationName),
              displayStringForOption: (l) => l['name'] as String,
              optionsBuilder: (tv) {
                if (tv.text.isEmpty) return locations;
                return locations.where((l) =>
                    (l['name'] as String).toLowerCase().contains(tv.text.toLowerCase()));
              },
              onSelected: (l) => setState(() {
                line.locationId  = l['id'] as int;
                line.locationName = l['name'] as String;
              }),
              fieldViewBuilder: (ctx, ctrl, fn, sub) => TextFormField(
                controller: ctrl, focusNode: fn,
                decoration: InputDecoration(
                  hintText: 'Location',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  filled: true, fillColor: Colors.white,
                ),
                onFieldSubmitted: (_) => sub(),
              ),
              optionsViewBuilder: (ctx, onSel, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8, borderRadius: BorderRadius.circular(10), color: Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero, shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final l = options.elementAt(i);
                        return ListTile(
                          dense: true,
                          title: Text(l['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          onTap: () => onSel(l),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Qty
          SizedBox(
            width: 72,
            child: TextFormField(
              key: ValueKey('qty_$index'),
              initialValue: line.quantity.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                filled: true, fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() { line.quantity = int.tryParse(v) ?? 1; }),
            ),
          ),
          const SizedBox(width: 4),
          // Delete
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300),
            onPressed: () => _removeManualLine(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Bulk Upload ─────────────────────────────────────────────────────────
  Widget _buildBulkTab(List<Map<String, dynamic>> designs, List<Map<String, dynamic>> locations) {
    final validRows   = _bulkRows.where((r) => r.isValid).length;
    final errorRows   = _bulkRows.where((r) => !r.isValid).length;
    final hasData     = _bulkRows.isNotEmpty;
    // Strict Validation: Cannot save if there's even 1 error
    final canSave     = hasData && errorRows == 0 && !_isSaving;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [



          // ── Upload zone ────────────────────────────────────────────────────
          InkWell(
            onTap: _isParsing ? null : () => _pickExcelFile(designs, locations),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: (_uploadedFileName != null
                    ? Border.all(color: AppColors.success, width: 2)
                    : Border.all(color: AppColors.divider, width: 1)),
              ),
              child: _isParsing
                  ? const Column(children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 12),
                      Text('Parsing Excel…', style: TextStyle(color: AppColors.textSecondary)),
                    ])
                  : Column(
                      children: [
                        Icon(
                          _uploadedFileName != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                          size: 48,
                          color: _uploadedFileName != null ? AppColors.success : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _uploadedFileName ?? 'Tap to choose Excel file (.xlsx)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _uploadedFileName != null ? AppColors.textPrimary : Colors.grey.shade500,
                          ),
                        ),
                        if (_uploadedFileName != null) ...[
                          const SizedBox(height: 4),
                          Text('Tap to replace', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Instructions card (Short) ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Instructions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('1. Download template & fill data.\n2. Ensure columns match: Design No, Location, Qty.\n3. Upload and review the table below for errors.', style: TextStyle(color: Colors.blue.shade900, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Template'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),



          // ── Preview table ──────────────────────────────────────────────────
          if (hasData) ...[
            // Summary row
            Row(children: [
              _summaryChip('${_bulkRows.length} rows', Colors.grey),
              const SizedBox(width: 8),
              _summaryChip('$validRows valid', Colors.green),
              if (errorRows > 0) ...[
                const SizedBox(width: 8),
                _summaryChip('$errorRows errors', Colors.red),
              ],
            ]),
            const SizedBox(height: 12),

            // Table
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppColors.primary.withAlpha(12),
                    child: const Row(children: [
                      Expanded(flex: 3, child: Text('Design No', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent))),
                      Expanded(flex: 2, child: Text('Location',  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent))),
                      SizedBox(width: 50, child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent))),
                      SizedBox(width: 80, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent))),
                    ]),
                  ),
                  // Data rows
                  ...List.generate(_bulkRows.length, (i) {
                    final row   = _bulkRows[i];
                    final isErr = !row.isValid;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: isErr ? Colors.red.shade50 : (i.isOdd ? Colors.grey.shade50 : Colors.white),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(row.rawDesignNo, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isErr ? Colors.red.shade700 : AppColors.textPrimary))),
                        Expanded(flex: 2, child: Text(row.rawLocation,  style: TextStyle(fontSize: 13, color: isErr ? Colors.red.shade700 : AppColors.textSecondary))),
                        SizedBox(width: 50, child: Text('${row.rawQty}', style: TextStyle(fontSize: 13, color: isErr ? Colors.red.shade700 : AppColors.textSecondary))),
                        SizedBox(
                          width: 80,
                          child: isErr
                              ? Tooltip(
                                  message: row.errorMsg ?? 'Invalid',
                                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                                    const SizedBox(width: 2),
                                    Text('Error', style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.bold)),
                                  ]),
                                )
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                                  Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                  SizedBox(width: 2),
                                  Text('OK', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                                ]),
                        ),
                      ]),
                    );
                  }),
                ],
              ),
            ),
            if (errorRows > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Fix errors in Excel and re-upload. Only valid rows will be saved.', style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
                ]),
              ),
            ],
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving 
                      ? 'Saving…' 
                      : (errorRows > 0 ? 'Fix $errorRows 🔴 errors first' : 'Save Purchase (${_bulkRows.length} rows)'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────────


  Widget _summaryChip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.shade200)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color.shade700)),
    );
  }
}
