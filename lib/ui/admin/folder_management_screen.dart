import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/product_providers.dart';
import '../../services/core_providers.dart';
import 'package:shopmanage/theme/app_theme.dart';
import '../../models/shop.dart';
import '../common/error_view.dart';
import '../common/searchable_selector.dart';
import 'admin_scaffold.dart';

class FolderManagementScreen extends ConsumerStatefulWidget {
  const FolderManagementScreen({super.key});

  @override
  ConsumerState<FolderManagementScreen> createState() => _FolderManagementScreenState();
}

class _FolderManagementScreenState extends ConsumerState<FolderManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(allFoldersProvider);
    final shopsAsync = ref.watch(shopsProvider);
    final activeShop = ref.watch(activeShopProvider);

    return AdminScaffold(
      title: activeShop == null ? 'All Folders' : 'Shop Folders',
      selectedShopId: activeShop?.id,
      onShopChanged: (val) {
        if (val == null) {
          ref.read(activeShopProvider.notifier).setShop(null);
        } else {
          shopsAsync.whenData((shops) {
            final shop = shops.firstWhere((s) => s.id == val);
            ref.read(activeShopProvider.notifier).setShop(shop);
          });
        }
      },
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
          onPressed: () => _showFolderDialog(context, ref, shopsAsync, initialShopId: activeShop?.id),
          tooltip: 'Add Folder',
        ),
      ],
      body: foldersAsync.when(
        data: (folders) {
          final filtered = activeShop == null 
              ? folders 
              : folders.where((f) => f['shop_id'] == activeShop.id).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    activeShop == null ? 'No folders found.' : 'No folders for this shop.',
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
              final folder = filtered[index];
              final isActive = folder['is_active'] as bool;
              final shopName = folder['shop']?['shop_name'] ?? 'N/A';
              
              return Card(
                elevation: 0,
                color: AppColors.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.divider, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isActive ? AppColors.success : Colors.grey).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isActive ? Icons.folder_rounded : Icons.folder_off_rounded, 
                        color: isActive ? AppColors.success : Colors.grey,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      folder['folder_name'], 
                      style: TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 14, 
                        color: isActive ? AppColors.textPrimary : AppColors.textSecondary.withOpacity(0.5),
                        decoration: isActive ? null : TextDecoration.lineThrough,
                        decorationColor: AppColors.textSecondary.withOpacity(0.5),
                        letterSpacing: -0.2
                      )
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.cardSales.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              shopName.toUpperCase(),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.cardSales, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: isActive,
                          onChanged: (val) => _toggleFolderStatus(context, ref, folder, val),
                          activeColor: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showFolderDialog(context, ref, shopsAsync, folder: folder),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(Icons.edit_note_rounded, color: AppColors.textSecondary.withOpacity(0.6), size: 24),
                            ),
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
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => ErrorView(
          error: err,
          onRetry: () => ref.invalidate(allFoldersProvider),
        ),
      ),
    );
  }

  Future<void> _showFolderDialog(
    BuildContext context, 
    WidgetRef ref, 
    AsyncValue<List<Shop>> shopsAsync,
    {Map<String, dynamic>? folder,
    int? initialShopId}
  ) async {
    final controller = TextEditingController(text: folder?['folder_name'] ?? '');
    int? selectedShopId = folder?['shop_id'] ?? initialShopId;
    final isEditing = folder != null;

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
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
                  Text(isEditing ? 'Edit Folder' : 'New Folder', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Folder Name',
                      hintText: 'e.g., Brand Name, Category',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  if (!isEditing)
                    shopsAsync.when(
                      data: (shops) {
                        final selectedShop = shops.where((s) => s.id == selectedShopId).firstOrNull;
                        final shopName = selectedShop?.shopName ?? 'Select Shop';
                        final shopMap = shops.map((s) => {'id': s.id, 'shop_name': s.shopName}).toList();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ASSIGN TO SHOP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => SearchableSelector.show(
                                context: context,
                                title: 'Select Shop',
                                items: shopMap,
                                labelKey: 'shop_name',
                                icon: Icons.storefront_rounded,
                                iconColor: AppColors.cardSales,
                                onSelected: (id) => setDialogState(() => selectedShopId = id),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 18, color: AppColors.cardSales),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                                    const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading shops'),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(isEditing ? 'Update' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && controller.text.trim().isNotEmpty && (isEditing || selectedShopId != null)) {
      try {
        if (isEditing) {
          await ref.read(productRepositoryProvider).updateFolder(
                folder['id'],
                controller.text.trim(),
                folder['is_active'],
              );
        } else {
          await ref.read(productRepositoryProvider).createFolder(
            controller.text.trim(),
            selectedShopId!,
          );
        }
        ref.invalidate(allFoldersProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder ${isEditing ? 'updated' : 'created'} successfully')),
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

  Future<void> _toggleFolderStatus(BuildContext context, WidgetRef ref, Map<String, dynamic> folder, bool status) async {
    try {
      await ref.read(productRepositoryProvider).updateFolder(
            folder['id'],
            folder['folder_name'],
            status,
          );
      ref.invalidate(allFoldersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
