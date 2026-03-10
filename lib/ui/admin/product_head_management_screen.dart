import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/product_providers.dart';
import '../../services/core_providers.dart';
import 'package:shopmanage/theme/app_theme.dart';
import '../../models/shop.dart';
import '../common/error_view.dart';
import 'admin_scaffold.dart';

class ProductHeadManagementScreen extends ConsumerStatefulWidget {
  const ProductHeadManagementScreen({super.key});

  @override
  ConsumerState<ProductHeadManagementScreen> createState() => _ProductHeadManagementScreenState();
}

class _ProductHeadManagementScreenState extends ConsumerState<ProductHeadManagementScreen> {
  int? _selectedShopId;

  @override
  Widget build(BuildContext context) {
    final headsAsync = ref.watch(allProductHeadsProvider);
    final foldersAsync = ref.watch(allFoldersProvider);
    final shopsAsync = ref.watch(shopsProvider);

    return AdminScaffold(
      title: _selectedShopId == null ? 'All Products' : 'Shop Products',
      selectedShopId: _selectedShopId,
      onShopChanged: (val) => setState(() => _selectedShopId = val),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
          onPressed: () => _showProductHeadDialog(context, ref, foldersAsync, shopsAsync, initialShopId: _selectedShopId),
          tooltip: 'Add Product',
        ),
      ],
      body: headsAsync.when(
        data: (heads) {
          final filtered = _selectedShopId == null 
              ? heads 
              : heads.where((h) => h['shop_id'] == _selectedShopId).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    _selectedShopId == null ? 'No products found.' : 'No products for this shop.',
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
              final folderName = head['folders']?['folder_name'] ?? 'No Folder';
              final shopName = head['shop']?['shop_name'] ?? 'No Shop';
              
              return Card(
                elevation: 0,
                color: AppColors.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.divider, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardPrice.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.layers_rounded, color: AppColors.cardPrice, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              head['product_name'], 
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary, letterSpacing: -0.2)
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${head['product_rate']}', 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.textPrimary, letterSpacing: -0.5)
                          ),
                          const SizedBox(height: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showProductHeadDialog(context, ref, foldersAsync, shopsAsync, head: head),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary.withOpacity(0.8)),
                                    const SizedBox(width: 4),
                                    Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary.withOpacity(0.8))),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
                    Row(
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
                    ),
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
}
