import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/stock_providers.dart';
import '../../services/core_providers.dart';
import '../../services/product_providers.dart';
import '../../services/log_service.dart';
import '../../models/product_head.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_translator.dart';
import '../common/error_view.dart';
import '../common/empty_state_view.dart';
import '../common/app_drawer.dart';
import 'design_history_sheet.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _searchQuery = '';
  String _filterMode = 'design'; // 'design' or 'location'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterStock(List<Map<String, dynamic>> stockList) {
    if (_searchQuery.isEmpty) return stockList;
    final query = _searchQuery.toLowerCase();
    return stockList.where((row) {
      if (_filterMode == 'design') {
        final design = row['products_design'] ?? {};
        final designNo = (design['design_no']?.toString() ?? '').toLowerCase();
        return designNo.contains(query);
      } else {
        final location = row['locations'] ?? {};
        final locationName = (location['name']?.toString() ?? '').toLowerCase();
        return locationName.contains(query);
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(shopStockProvider);
    final activeShop = ref.watch(activeShopProvider);
    final shopName = activeShop?.shopName ?? '';
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Builder(builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Stock View', 
                style: TextStyle(
                  fontWeight: FontWeight.w800, 
                  color: AppColors.textPrimary,
                  fontSize: isMobile ? 16 : 20,
                )
              ),
              if (shopName.isNotEmpty)
                Text(
                  shopName,
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 11, 
                    fontWeight: FontWeight.bold, 
                    color: AppColors.accent, 
                    letterSpacing: 0.5
                  ),
                ),
            ],
          );
        }),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Builder(builder: (context) {
            if (isMobile) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.primary),
                onSelected: (value) {
                  if (value == 'add') _showAddStockDialog(context, ref);
                  if (value == 'transfer') _showTransferStockDialog(context, ref);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'add', child: Row(children: [Icon(Icons.add_shopping_cart, size: 18), SizedBox(width: 8), Text('Add Stock')])),
                  const PopupMenuItem(value: 'transfer', child: Row(children: [Icon(Icons.compare_arrows, size: 18), SizedBox(width: 8), Text('Transfer Stock')])),
                ],
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAppBarAction(Icons.add_shopping_cart_rounded, 'Add Stock', () => _showAddStockDialog(context, ref), AppColors.primary),
                const SizedBox(width: 8),
                _buildAppBarAction(Icons.compare_arrows_rounded, 'Transfer Stock', () => _showTransferStockDialog(context, ref), AppColors.primaryDim),
              ],
            );
          }),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/stock'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: stockAsync.when(
            data: (stockList) {
              final filteredList = _filterStock(stockList);

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(shopStockProvider),
                color: AppColors.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    // ── Search & Filter Panel ──────────────────────────────────
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _searchController,
                                onChanged: (val) => setState(() => _searchQuery = val),
                                decoration: InputDecoration(
                                  hintText: _filterMode == 'design' ? 'Search design...' : 'Search location...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  suffixIcon: _searchQuery.isNotEmpty 
                                    ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      })
                                    : null,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Builder(builder: (context) {
                                final isMobile = MediaQuery.of(context).size.width < 600;
                                final chips = [
                                  _FilterChip(
                                    label: 'Design NO',
                                    isSelected: _filterMode == 'design',
                                    onTap: () => setState(() => _filterMode = 'design'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'Location',
                                    isSelected: _filterMode == 'location',
                                    onTap: () => setState(() => _filterMode = 'location'),
                                  ),
                                ];
                                
                                final countText = Text(
                                  '${filteredList.length} Items',
                                  style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 11, fontWeight: FontWeight.bold),
                                );

                                if (isMobile) {
                                  return Column(
                                    children: [
                                      Row(children: chips),
                                      const SizedBox(height: 12),
                                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [countText]),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    ...chips,
                                    const Spacer(),
                                    countText,
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Table Header ───────────────────────────────────────────
                    SliverStickyHeader(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF475569),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Builder(builder: (context) {
                          return Row(
                            children: [
                              Expanded(flex: 3, child: Text('DESIGN', style: TextStyle(color: Colors.white70, fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                              Expanded(flex: 3, child: Text('LOCATION', style: TextStyle(color: Colors.white70, fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                              Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                            ],
                          );
                        }),
                      ),
                    ),

                    // ── Data Rows ──────────────────────────────────────────────
                    if (filteredList.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateView(
                          title: 'No Matching Stock',
                          message: _searchQuery.isEmpty ? 'There is no stock available in this warehouse.' : 'Try adjusting your search filters.',
                          icon: Icons.inventory_2_outlined,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final row = filteredList[index];
                              final design = row['products_design'] ?? {};
                              final location = row['locations'] ?? {};
                              final qty = (row['quantity'] as num).toInt();
                              final isLow = qty < 10;
                              final isLast = index == filteredList.length - 1;

                              return RepaintBoundary(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : null,
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          design['design_no']?.toString() ?? '-',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                location['name']?.toString() ?? 'Warehouse',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isLow ? Colors.orange.shade50 : Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                qty.toString(),
                                                style: TextStyle(
                                                  color: isLow ? Colors.orange.shade700 : Colors.green.shade700,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 13,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.history_rounded, size: 20),
                                              color: AppColors.primary,
                                              tooltip: 'View History',
                                              onPressed: () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (context) => DesignHistorySheet(
                                                    designId: design['id'] as int,
                                                    designNo: design['design_no']?.toString() ?? '-',
                                                  ),
                                                );
                                              },
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: filteredList.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => ErrorView(
              error: err,
              onRetry: () => ref.invalidate(shopStockProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarAction(IconData icon, String tooltip, VoidCallback onTap, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  void _showAddStockDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AddStockDialog(),
    );
  }

  void _showTransferStockDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _TransferStockDialog(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class SliverStickyHeader extends StatelessWidget {
  final Widget child;
  const SliverStickyHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverDelegate(child: child),
    );
  }
}

class _SliverDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverDelegate({required this.child});

  @override
  double get minExtent => 38;
  @override
  double get maxExtent => 38;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SliverDelegate oldDelegate) => false;
}

// ─── Add Stock Dialog ─────────────────────────────────────────────
class _AddStockDialog extends ConsumerStatefulWidget {
  const _AddStockDialog();

  @override
  ConsumerState<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends ConsumerState<_AddStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _designController = TextEditingController();

  int? _selectedProductHeadId;
  int? _selectedLocationId;
  String? _selectedLocationName;
  int _quantity = 1;
  bool _isSaving = false;

  @override
  void dispose() {
    _designController.dispose();
    super.dispose();
  }

  void _showRenameLocationDialog(BuildContext context, WidgetRef ref, int locationId, String currentName) {
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Rename Location'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Location Name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Cannot be empty';
                    if (val.trim() == currentName) return 'Name is unchanged';
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            try {
                              await ref.read(supabaseClientProvider).from('locations').update({
                                'name': controller.text.trim(),
                              }).eq('id', locationId);

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('✅ Location renamed successfully!'),
                                    backgroundColor: Colors.green.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }

                              setState(() {
                                _selectedLocationName = controller.text.trim();
                              });

                              ref.invalidate(locationsProvider);
                              ref.invalidate(shopStockProvider);
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ ${ErrorTranslator.translate(e)}'),
                                    backgroundColor: Colors.red.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Rename'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2, color: Colors.blueGrey.shade700)),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildAutocomplete<T extends Object>({
    required String label,
    required IconData icon,
    required String? initialValue,
    required Iterable<T> Function(String query) suggestions,
    required void Function(T item) onSelected,
    required String Function(T) displayStringForOption,
    void Function(T item)? onEditOption,
  }) {
    return Autocomplete<T>(
      initialValue: TextEditingValue(text: initialValue ?? ''),
      displayStringForOption: displayStringForOption,
      optionsBuilder: (TextEditingValue textEditingValue) {
        return suggestions(textEditingValue.text);
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: _inputDecoration(label, icon).copyWith(
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
          ),
          onFieldSubmitted: (String value) => onFieldSubmitted(),
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
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayStringForOption(option),
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800),
                            ),
                          ),
                          if (onEditOption != null)
                            GestureDetector(
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                onEditOption(option);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.edit, size: 16, color: Colors.blue.shade600),
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
  }

  @override
  Widget build(BuildContext context) {
    final productHeadsAsync = ref.watch(productHeadsProvider);
    final locationsAsync = ref.watch(locationsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: Theme.of(context).primaryColor, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('Inventory Update', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 4),
                  Text('Add new stock to your system', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 28),

                  // Design Details
                  _sectionHeader('DESIGN DETAILS'),
                  TextFormField(
                    controller: _designController,
                    decoration: _inputDecoration('Design Number', Icons.tag, hint: 'e.g. SL-06-5227'),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Design number is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Product Head
                  productHeadsAsync.when(
                    data: (heads) => _buildAutocomplete<ProductHead>(
                      label: 'Product Head',
                      icon: Icons.account_tree_rounded,
                      initialValue: null,
                      suggestions: (query) => heads.where((h) => h.productName.toLowerCase().contains(query.toLowerCase())),
                      onSelected: (head) => setState(() => _selectedProductHeadId = head.id),
                      displayStringForOption: (head) => head.productName,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading: $e'),
                  ),
                  const SizedBox(height: 24),

                  // Stock Placement
                  _sectionHeader('STOCK PLACEMENT'),
                  locationsAsync.when(
                    data: (locations) => _buildAutocomplete<Map<String, dynamic>>(
                      label: 'Storage Location',
                      icon: Icons.location_on_rounded,
                      initialValue: _selectedLocationName,
                      suggestions: (query) => locations.where((l) => (l['name'] as String).toLowerCase().contains(query.toLowerCase())),
                      onSelected: (loc) => setState(() {
                        _selectedLocationId = loc['id'] as int;
                        _selectedLocationName = loc['name'] as String;
                      }),
                      displayStringForOption: (loc) => loc['name'] as String,
                      onEditOption: (loc) {
                        _showRenameLocationDialog(context, ref, loc['id'] as int, loc['name'] as String);
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading: $e'),
                  ),
                  const SizedBox(height: 16),

                  // Quantity
                  TextFormField(
                    initialValue: '1',
                    decoration: _inputDecoration('Quantity', Icons.tag),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _quantity = int.tryParse(val) ?? 1,
                    validator: (val) {
                      final n = int.tryParse(val ?? '');
                      if (n == null || n < 1) return 'Enter a valid quantity';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: Text('Discard', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Save Stock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    if (!_formKey.currentState!.validate() || _selectedProductHeadId == null || _selectedLocationId == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final activeShop = ref.read(activeShopProvider);
    if (activeShop == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final nav = Navigator.of(context);
    final scaffoldMsg = ScaffoldMessenger.of(context);

    try {
      await ref.read(stockRepositoryProvider).addStock(
        shopId: activeShop.id,
        designNo: _designController.text.trim(),
        productHeadId: _selectedProductHeadId!,
        locationId: _selectedLocationId!,
        quantity: _quantity,
      );
      if (mounted) {
        ref.read(logServiceProvider).success('Stock', 'Added ${_quantity} units of "${_designController.text.trim()}" to "${_selectedLocationName ?? 'location'}"');
        ref.invalidate(shopStockProvider);
        nav.pop();
        scaffoldMsg.showSnackBar(
          SnackBar(
            content: const Text('✅ Stock Added successfully!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e, stack) {
      ref.read(logServiceProvider).error('Stock', 'Failed to add stock "${_designController.text.trim()}"', e, stack);
      if (mounted) {
        scaffoldMsg.showSnackBar(
          SnackBar(
            content: Text('❌ ${ErrorTranslator.translate(e)}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ─── Transfer Stock Dialog ─────────────────────────────────────────
class _TransferStockDialog extends ConsumerStatefulWidget {
  const _TransferStockDialog();

  @override
  ConsumerState<_TransferStockDialog> createState() => _TransferStockDialogState();
}

class _TransferStockDialogState extends ConsumerState<_TransferStockDialog> {
  final _formKey = GlobalKey<FormState>();
  
  Map<String, dynamic>? _selectedDesign;
  int? _fromLocationId;
  int? _toLocationId;
  int _quantity = 1;
  int _maxAvailableQty = 0;
  final _qtyController = TextEditingController(text: '1');
  
  bool _isLoadingLocations = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _availableLocations = [];

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2, color: Colors.blueGrey.shade700)),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      labelStyle: TextStyle(color: Colors.grey.shade600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildAutocomplete<T extends Object>({
    required String label,
    required IconData icon,
    required String? initialValue,
    required Iterable<T> Function(String query) suggestions,
    required void Function(T item) onSelected,
    required String Function(T) displayStringForOption,
    Widget Function(BuildContext, TextEditingController, FocusNode, VoidCallback)? fieldViewBuilderCustom,
  }) {
    return Autocomplete<T>(
      initialValue: TextEditingValue(text: initialValue ?? ''),
      displayStringForOption: displayStringForOption,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return suggestions('');
        return suggestions(textEditingValue.text);
      },
      onSelected: onSelected,
      fieldViewBuilder: fieldViewBuilderCustom ??
          (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: _inputDecoration(label, icon).copyWith(
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              ),
              onFieldSubmitted: (String value) => onFieldSubmitted(),
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
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 350),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        displayStringForOption(option),
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800),
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
  }

  Future<void> _fetchAvailableLocations(int designId) async {
    setState(() {
      _isLoadingLocations = true;
      _fromLocationId = null;
      _maxAvailableQty = 0;
      _quantity = 1;
    });

    try {
      final activeShop = ref.read(activeShopProvider);
      if (activeShop == null) return;
      
      final locations = await ref.read(stockRepositoryProvider).getAvailableLocationsForDesign(activeShop.id, designId);
      
      setState(() {
        _availableLocations = locations;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorTranslator.translate(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocations = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final designsAsync = ref.watch(designsProvider);
    final locationsAsync = ref.watch(locationsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.compare_arrows_rounded, color: Colors.orange, size: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Transfer Stock', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 4),
                  Text('Move inventory between locations', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 28),

                  _sectionHeader('1. SELECT DESIGN'),
                  designsAsync.when(
                    data: (designs) => _buildAutocomplete<Map<String, dynamic>>(
                      label: 'Design Number',
                      icon: Icons.tag_rounded,
                      initialValue: null,
                      suggestions: (query) {
                        return designs.where((d) => (d['design_no'] as String).toLowerCase().contains(query.toLowerCase())).take(10);
                      },
                      onSelected: (design) {
                        setState(() {
                          _selectedDesign = design;
                        });
                        _fetchAvailableLocations(design['id'] as int);
                      },
                      displayStringForOption: (design) {
                        return design['design_no'] as String;
                      },
                      fieldViewBuilderCustom: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: _inputDecoration('Design Number', Icons.tag_rounded).copyWith(
                            suffixIcon: _selectedDesign != null
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                                    onPressed: () {
                                      controller.clear();
                                      setState(() {
                                        _selectedDesign = null;
                                        _availableLocations = [];
                                        _fromLocationId = null;
                                        _toLocationId = null;
                                        _maxAvailableQty = 0;
                                        _quantity = 1;
                                      });
                                    },
                                    tooltip: 'Change Design',
                                  )
                                : const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                          ),
                          onFieldSubmitted: (String value) => onFieldSubmitted(),
                        );
                      },
                    ),
                    loading: () => const LinearProgressIndicator(color: Colors.orange),
                    error: (e, _) => Text('Error loading: $e'),
                  ),
                  const SizedBox(height: 24),

                  if (_selectedDesign != null) ...[
                    _sectionHeader('2. AVAILABLE STOCK'),
                    if (_isLoadingLocations)
                      const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.orange)))
                    else if (_availableLocations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                        child: Row(
                          children: [
                            Icon(Icons.warning_rounded, color: Colors.red.shade400, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text('No stock available for this design in any location.', style: TextStyle(color: Colors.red.shade700))),
                          ],
                        ),
                      )
                    else 
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blueGrey.shade100)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select source location:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableLocations.map((loc) {
                                final locData = loc['locations'] ?? {};
                                final isSelected = _fromLocationId == locData['id'];
                                return ChoiceChip(
                                  label: Text('${locData['name']} (${loc['quantity']})'),
                                  selected: isSelected,
                                  selectedColor: Colors.orange,
                                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey.shade800, fontWeight: FontWeight.w600),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _fromLocationId = locData['id'] as int;
                                        _maxAvailableQty = loc['quantity'] as int;
                                        if (_quantity > _maxAvailableQty) _quantity = _maxAvailableQty;
                                        _qtyController.text = _quantity.toString();
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],

                  if (_fromLocationId != null) ...[
                    _sectionHeader('3. DESTINATION & QUANTITY'),
                    locationsAsync.when(
                      data: (locations) => _buildAutocomplete<Map<String, dynamic>>(
                        label: 'To Location',
                        icon: Icons.location_on_rounded,
                        initialValue: null,
                        suggestions: (query) => locations
                            .where((l) => (l['name'] as String).toLowerCase().contains(query.toLowerCase()))
                            .take(5),
                        onSelected: (loc) => setState(() {
                          _toLocationId = loc['id'] as int;
                        }),
                        displayStringForOption: (loc) => loc['name'] as String,
                      ),
                      loading: () => const LinearProgressIndicator(color: Colors.orange),
                      error: (e, _) => Text('Error loading: $e'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: _inputDecoration('Transfer Quantity', Icons.tag).copyWith(
                        helperText: 'Max available: $_maxAvailableQty',
                        helperStyle: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                      ),
                      keyboardType: TextInputType.number,
                      controller: _qtyController,
                      onChanged: (val) => _quantity = int.tryParse(val) ?? 1,
                      validator: (val) {
                        final n = int.tryParse(val ?? '');
                        if (n == null || n < 1) return 'Enter a valid quantity';
                        if (n > _maxAvailableQty) return 'Cannot transfer more than $_maxAvailableQty';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: (_isSaving || _selectedDesign == null || _fromLocationId == null || _toLocationId == null) ? null : _submitTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          disabledBackgroundColor: Colors.orange.shade200,
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_fromLocationId == _toLocationId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Source and destination locations must be different.'), backgroundColor: Colors.red.shade600),
      );
      return;
    }

    setState(() => _isSaving = true);

    final activeShop = ref.read(activeShopProvider);
    if (activeShop == null) return;

    final nav = Navigator.of(context);
    final scaffoldMsg = ScaffoldMessenger.of(context);

    try {
      await ref.read(stockRepositoryProvider).transferStock(
        shopId: activeShop.id,
        designId: _selectedDesign!['id'] as int,
        fromLocationId: _fromLocationId!,
        toLocationId: _toLocationId!,
        quantity: _quantity,
      );
      
      if (mounted) {
        ref.read(logServiceProvider).success('Stock', 'Transferred ${_quantity} units of design #${_selectedDesign!['design_no']}');
        ref.invalidate(shopStockProvider);
        nav.pop();
        scaffoldMsg.showSnackBar(
          SnackBar(
            content: const Text('🔁 Stock successfully transferred!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e, stack) {
      ref.read(logServiceProvider).error('Stock', 'Stock transfer failed for design #${_selectedDesign?['design_no'] ?? 'unknown'}', e, stack);
      if (mounted) {
        scaffoldMsg.showSnackBar(
          SnackBar(
            content: Text('❌ Transfer failed: ${ErrorTranslator.translate(e)}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
