import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/product_providers.dart';
import '../../services/core_providers.dart';
import 'package:shopmanage/theme/app_theme.dart';
import '../../models/shop.dart';
import 'package:intl/intl.dart';
import '../common/error_view.dart';
import 'admin_scaffold.dart';

class ProductHeadManagementScreen extends ConsumerStatefulWidget {
  const ProductHeadManagementScreen({super.key});

  @override
  ConsumerState<ProductHeadManagementScreen> createState() => _ProductHeadManagementScreenState();
}

class _ProductHeadManagementScreenState extends ConsumerState<ProductHeadManagementScreen> {
  bool _isBulkMode = false;
  bool _applyToPartiesGlobally = true;
  final Map<int, int> _adjustments = {}; // ProductID -> AdjustmentAmount
  final Map<int, TextEditingController> _adjustmentControllers = {};
  final TextEditingController _globalAdjustmentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _globalAdjustmentController.dispose();
    for (final controller in _adjustmentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _enterBulkMode() {
    setState(() {
      _isBulkMode = true;
      _adjustments.clear();
      for (final controller in _adjustmentControllers.values) {
        controller.dispose();
      }
      _adjustmentControllers.clear();
      _globalAdjustmentController.clear();
    });
  }

  void _exitBulkMode() {
    setState(() {
      _isBulkMode = false;
      _adjustments.clear();
      for (final controller in _adjustmentControllers.values) {
        controller.dispose();
      }
      _adjustmentControllers.clear();
    });
  }

  Future<void> _saveBulkAdjustments(int? shopId) async {
    if (shopId == null) return;
    
    final validAdjustments = _adjustments.entries
        .where((e) => e.value != 0)
        .map((e) => {'product_id': e.key, 'change_amount': e.value})
        .toList();

    if (validAdjustments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No adjustments to save')),
      );
      _exitBulkMode();
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(productRepositoryProvider).batchBulkUpdateProducts(
        adjustments: validAdjustments,
        shopId: shopId,
        applyToParties: _applyToPartiesGlobally,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully updated ${validAdjustments.length} products')),
        );
        ref.invalidate(allProductHeadsProvider);
        _exitBulkMode();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headsAsync = ref.watch(allProductHeadsProvider);
    final foldersAsync = ref.watch(allFoldersProvider);
    final shopsAsync = ref.watch(shopsProvider);
    final activeShop = ref.watch(activeShopProvider);

    return AdminScaffold(
      title: _isBulkMode 
          ? 'Bulk Edit' 
          : (activeShop == null ? 'All Products' : 'Shop Products'),
      selectedShopId: activeShop?.id,
      onShopChanged: _isBulkMode ? null : (val) {
        if (val == null) {
          ref.read(activeShopProvider.notifier).setShop(null);
        } else {
          shopsAsync.whenData((shops) {
            final shop = shops.firstWhere((s) => s.id == val);
            ref.read(activeShopProvider.notifier).setShop(shop);
          });
        }
      },
      actions: _isBulkMode 
        ? [
            _buildAppBarAction(
              icon: Icons.close_rounded,
              onPressed: _isSaving ? null : _exitBulkMode,
              tooltip: 'Cancel',
              iconColor: Colors.grey.shade700,
            ),
            _buildAppBarAction(
              icon: Icons.check_circle_rounded,
              onPressed: _isSaving ? null : () => _saveBulkAdjustments(activeShop?.id),
              tooltip: 'Save All',
              isSaving: _isSaving,
              iconColor: AppColors.success,
            ),
          ]
        : [
            _buildAppBarAction(
              icon: Icons.price_change_rounded,
              onPressed: _enterBulkMode,
              tooltip: 'New Rate Update',
              iconColor: AppColors.cardPrice,
            ),
            _buildAppBarAction(
              icon: Icons.add_circle_rounded,
              onPressed: () => _showProductHeadDialog(context, ref, foldersAsync, shopsAsync, initialShopId: activeShop?.id),
              tooltip: 'Add Product',
              iconColor: AppColors.primary,
            ),
          ],
      body: Column(
        children: [
          if (_isBulkMode) _buildBulkHeader(),
          Expanded(
            child: headsAsync.when(
        data: (heads) {
          final filtered = activeShop == null 
              ? heads 
              : heads.where((h) => h['shop_id'] == activeShop.id).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    activeShop == null ? 'No products found.' : 'No products for this shop.',
                    style: TextStyle(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final head = filtered[index];
              final productId = head['id'] as int;
              final currentRate = head['product_rate'] as int;
              final folderName = head['folders']?['folder_name'] ?? 'No Folder';
              final shopName = head['shop']?['shop_name'] ?? 'No Shop';
              final isSmall = MediaQuery.of(context).size.width < 450;
              
              return Card(
                elevation: 0,
                color: _isBulkMode ? AppColors.primary.withOpacity(0.02) : AppColors.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _isBulkMode && (_adjustments[productId] ?? 0) != 0 
                        ? AppColors.primary.withOpacity(0.5) 
                        : AppColors.divider, 
                    width: _isBulkMode && (_adjustments[productId] ?? 0) != 0 ? 2 : 1
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _isBulkMode 
                    ? Row(
                        children: [
                          _buildIconBox(),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: Text(
                              head['product_name'], 
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary, letterSpacing: -0.2),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildHistoryButton(context, head),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _buildCompactAdjustmentField(productId, _adjustments[productId] ?? 0),
                          ),
                          const SizedBox(width: 8),
                          _buildNewRateColumn(currentRate + (_adjustments[productId] ?? 0), _adjustments[productId] ?? 0),
                        ],
                      )
                    : isSmall 
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildIconBox(),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      head['product_name'], 
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary, letterSpacing: -0.2)
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildTag(shopName, AppColors.cardSales),
                                  _buildTag(folderName, AppColors.cardStock),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₹$currentRate', 
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary)
                                  ),
                                  _buildEditButton(context, ref, foldersAsync, shopsAsync, head),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              _buildIconBox(),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text( head['product_name'], 
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary, letterSpacing: -0.2)
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _buildTag(shopName, AppColors.cardSales),
                                        _buildTag(folderName, AppColors.cardStock),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹$currentRate', 
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary, letterSpacing: -0.5)
                                  ),
                                  const SizedBox(height: 4),
                                  _buildEditButton(context, ref, foldersAsync, shopsAsync, head),
                                ],
                              ),
                            ],
                          ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => ErrorView(
          error: err,
          onRetry: () => ref.invalidate(allProductHeadsProvider),
        ),
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBox() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardPrice.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.layers_rounded, color: AppColors.cardPrice, size: 20),
    );
  }

  Widget _buildHistoryButton(BuildContext context, Map<String, dynamic> head) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showHistoryBottomSheet(context, head),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.1)),
          ),
          child: Icon(Icons.history_rounded, size: 16, color: Colors.blueGrey.withOpacity(0.7)),
        ),
      ),
    );
  }


  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
      ),
    );
  }

  Future<void> _showProductHeadDialog(
    BuildContext context, 
    WidgetRef ref, 
    AsyncValue<List<Map<String, dynamic>>> foldersAsync,
    AsyncValue<List<Shop>> shopsAsync,
    {Map<String, dynamic>? head,
    int? initialShopId}
  ) async {
    final nameController = TextEditingController(text: head?['product_name'] ?? '');
    final rateController = TextEditingController(text: head?['product_rate']?.toString() ?? '');
    int? selectedFolderId = head?['folder_id'];
    int? selectedShopId = head?['shop_id'] ?? initialShopId;
    final isEditing = head != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedShopId != null)
                    shopsAsync.when(
                      data: (shops) {
                        final shopName = shops.firstWhere((s) => s.id == selectedShopId).shopName;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SHOP: ${shopName.toUpperCase()}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.5),
                          ),
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  Text(isEditing ? 'Edit Product' : 'New Product', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(builder: (context) {
                      final isMobileDialog = MediaQuery.of(context).size.width < 500;
                      if (isMobileDialog) {
                        return Column(
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Product Name',
                                hintText: 'e.g. Green 1mm',
                                border: OutlineInputBorder(),
                              ),
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: rateController,
                              decoration: const InputDecoration(
                                labelText: 'Rate',
                                hintText: '550',
                                border: OutlineInputBorder(),
                                prefixText: '₹ ',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Product Name',
                                hintText: 'e.g. Green 1mm',
                                border: OutlineInputBorder(),
                              ),
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: rateController,
                              decoration: const InputDecoration(
                                labelText: 'Rate',
                                hintText: '550',
                                border: OutlineInputBorder(),
                                prefixText: '₹ ',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                    foldersAsync.when(
                      data: (folders) => DropdownButtonFormField<int>(
                        value: selectedFolderId,
                        decoration: const InputDecoration(
                          labelText: 'Select Folder',
                          border: OutlineInputBorder(),
                        ),
                        items: folders.map((f) => DropdownMenuItem(
                          value: f['id'] as int,
                          child: Text(f['folder_name']),
                        )).toList(),
                        onChanged: (val) => setDialogState(() => selectedFolderId = val),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error loading folders'),
                    ),
                    const SizedBox(height: 16),
                    if (!isEditing) // Only allow shop selection for new products
                      shopsAsync.when(
                        data: (shops) => DropdownButtonFormField<int>(
                          value: selectedShopId,
                          decoration: const InputDecoration(
                            labelText: 'Select Shop',
                            border: OutlineInputBorder(),
                          ),
                          items: shops.map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.shopName),
                          )).toList(),
                          onChanged: (val) => setDialogState(() => selectedShopId = val),
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Error loading shops'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(isEditing ? 'Update' : 'Create'),
                ),
              ],
            );
          }
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty && selectedFolderId != null && (isEditing || selectedShopId != null)) {
      try {
        final rate = int.tryParse(rateController.text.trim()) ?? 0;
        if (isEditing) {
          await ref.read(productRepositoryProvider).updateProductHead(
                id: head['id'],
                name: nameController.text.trim(),
                rate: rate,
                folderId: selectedFolderId!,
              );
        } else {
          await ref.read(productRepositoryProvider).createProductHead(
                name: nameController.text.trim(),
                rate: rate,
                folderId: selectedFolderId!,
                shopId: selectedShopId!,
              );
        }
        ref.invalidate(allProductHeadsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Product ${isEditing ? 'updated' : 'created'} successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildBulkHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        border: const Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Rate Adjustment Mode',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
                Text(
                  'Individual adjustments will update party prices.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Text('Update Party Prices', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              SizedBox(
                height: 32,
                child: Switch(
                  value: _applyToPartiesGlobally,
                  onChanged: (val) => setState(() => _applyToPartiesGlobally = val),
                  activeThumbColor: AppColors.success,
                  activeTrackColor: AppColors.success.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAdjustmentField(int productId, int adj) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: adj != 0 ? AppColors.primary.withOpacity(0.3) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: TextField(
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        keyboardType: TextInputType.number,
        controller: _adjustmentControllers.putIfAbsent(productId, () => TextEditingController(text: adj == 0 ? '' : adj.toString())),
        decoration: InputDecoration(
          hintText: 'Rate +/-',
          isDense: true,
          hintStyle: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.3), fontWeight: FontWeight.normal),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          prefixText: adj > 0 ? '+' : '',
          prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          suffixIcon: adj != 0 ? GestureDetector(
            onTap: () {
              setState(() {
                _adjustments.remove(productId);
                _adjustmentControllers[productId]?.clear();
              });
            },
            child: Icon(Icons.cancel_rounded, size: 14, color: AppColors.primary.withOpacity(0.5)),
          ) : null,
        ),
        onChanged: (val) {
          setState(() {
            _adjustments[productId] = int.tryParse(val) ?? 0;
          });
        },
      ),
    );
  }

  Widget _buildNewRateColumn(int newRate, int adj) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: adj != 0 ? AppColors.success.withOpacity(0.08) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('NEW RATE', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: adj != 0 ? AppColors.success : AppColors.textSecondary, letterSpacing: 0.2)),
          const SizedBox(height: 2),
          Text(
            '₹$newRate',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: adj != 0 ? AppColors.success : AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton(BuildContext context, WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> foldersAsync, AsyncValue<List<Shop>> shopsAsync, Map<String, dynamic> head) {
    return IntrinsicWidth(
      child: TextButton.icon(
        onPressed: () => _showProductHeadDialog(context, ref, foldersAsync, shopsAsync, head: head),
        icon: const Icon(Icons.edit_note_rounded, size: 16),
        label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          backgroundColor: AppColors.primary.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _showHistoryBottomSheet(BuildContext context, Map<String, dynamic> head) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final historyAsync = ref.watch(productRateHistoryProvider(head['id']));
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                  Text(
                    '${head['product_name']} - Rate History',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: historyAsync.when(
                      data: (history) {
                        if (history.isEmpty) {
                          return const Center(child: Text('No bulk rate changes recorded.', style: TextStyle(color: Colors.grey)));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: history.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final record = history[index];
                            final change = record['change_amount'] as int;
                            final date = DateTime.parse(record['created_at']).toLocal();
                            final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
                            
                            final isIncrease = change > 0;
                            
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: isIncrease ? AppColors.success.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                child: Icon(
                                  isIncrease ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  color: isIncrease ? AppColors.success : Colors.red,
                                ),
                              ),
                              title: Text(
                                '${isIncrease ? 'Increased' : 'Decreased'} by ₹${change.abs()}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Changed from ₹${record['previous_rate']} to ₹${record['new_rate']}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              trailing: Text(
                                formattedDate,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isSaving = false,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: isSaving 
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: iconColor ?? AppColors.primary, strokeWidth: 2))
            : Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      ),
    );
  }
}
