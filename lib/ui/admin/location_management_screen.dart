import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/core_providers.dart';
import 'package:shopmanage/theme/app_theme.dart';
import '../../models/shop.dart';
import '../common/error_view.dart';
import 'admin_scaffold.dart';

class LocationManagementScreen extends ConsumerStatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  ConsumerState<LocationManagementScreen> createState() => _LocationManagementScreenState();
}

class _LocationManagementScreenState extends ConsumerState<LocationManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(allLocationsProvider);
    final shopsAsync = ref.watch(shopsProvider);
    final activeShop = ref.watch(activeShopProvider);

    return AdminScaffold(
      title: activeShop == null ? 'All Locations' : 'Shop Locations',
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
          onPressed: () => _showLocationDialog(context, ref, shopsAsync, initialShopId: activeShop?.id),
          tooltip: 'Add Location',
        ),
      ],
      body: locationsAsync.when(
        data: (locations) {
          final filtered = activeShop == null 
              ? locations 
              : locations.where((l) => l['shop_id'] == activeShop.id).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    activeShop == null ? 'No locations found.' : 'No locations for this shop.',
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
              final loc = filtered[index];
              final shopName = loc['shop']['shop_name'];
              
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
                        color: AppColors.cardStock.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: AppColors.cardStock, size: 24),
                    ),
                    title: Text(
                      loc['name'], 
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary, letterSpacing: -0.2)
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
                    trailing: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showLocationDialog(context, ref, shopsAsync, location: loc),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.edit_note_rounded, color: AppColors.textSecondary.withOpacity(0.6), size: 24),
                        ),
                      ),
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
          onRetry: () => ref.invalidate(allLocationsProvider),
        ),
      ),
    );
  }

  Future<void> _showLocationDialog(
    BuildContext context, 
    WidgetRef ref, 
    AsyncValue<List<Shop>> shopsAsync, 
    {Map<String, dynamic>? location,
    int? initialShopId}
  ) async {
    final nameController = TextEditingController(text: location?['name'] ?? '');
    int? selectedShopId = location?['shop_id'] ?? initialShopId;
    final isEditing = location != null;

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
                  Text(isEditing ? 'Edit Location' : 'New Location', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Location Name',
                      hintText: 'e.g., Godown, Shop Floor',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
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
                      onChanged: isEditing ? null : (val) => setDialogState(() => selectedShopId = val),
                    ),
                    loading: () => const CircularProgressIndicator(),
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
          }
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty && selectedShopId != null) {
      try {
        if (isEditing) {
          await ref.read(shopRepositoryProvider).updateLocation(location['id'], nameController.text.trim());
        } else {
          await ref.read(shopRepositoryProvider).createLocation(nameController.text.trim(), selectedShopId!);
        }
        ref.invalidate(allLocationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location ${isEditing ? 'updated' : 'created'} successfully')),
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
