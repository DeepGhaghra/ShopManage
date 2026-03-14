import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/log_service.dart';
import '../../services/core_providers.dart';
import '../../models/shop.dart';
import '../common/error_view.dart';
import 'package:shopmanage/theme/app_theme.dart';
import 'admin_scaffold.dart';

class ShopManagementScreen extends ConsumerWidget {
  const ShopManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(shopsProvider);

    return AdminScaffold(
      title: 'Manage Shops',
      body: shopsAsync.when(
        data: (shops) {
          if (shops.isEmpty) {
            return Center(child: Text('No shops found.', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.5), fontWeight: FontWeight.w600)));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final shop = shops[index];
              return _ShopManagementCard(shop: shop);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => ErrorView(
          error: err,
          onRetry: () => ref.invalidate(shopsProvider),
        ),
      ),
    );
  }
}

class _ShopManagementCard extends ConsumerWidget {
  final Shop shop;
  const _ShopManagementCard({required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.shopName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary, letterSpacing: -0.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${shop.id} | ${shop.shopShortName ?? "NO CODE"}',
                        style: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showEditShopDialog(context, ref),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.edit_note_rounded, color: AppColors.textSecondary.withOpacity(0.6), size: 26),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: AppColors.divider, thickness: 1.5),
            ),
            _buildDetailRow('Print Display Name', shop.shopPrintName),
            const SizedBox(height: 12),
            _buildDetailRow('Establishment Date', shop.createdAt.toString().split(' ')[0]),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontWeight: FontWeight.w500, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14)),
      ],
    );
  }

  Future<void> _showEditShopDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController(text: shop.shopName);
    final printNameController = TextEditingController(text: shop.shopPrintName);
    final shortNameController = TextEditingController(text: shop.shopShortName);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Shop Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Shop Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: printNameController,
              decoration: const InputDecoration(labelText: 'Shop Print Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: shortNameController,
              decoration: const InputDecoration(labelText: 'Short Name (Code)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final log = ref.read(logServiceProvider);
        await ref.read(shopRepositoryProvider).updateShop(shop.id, {
          'shop_name': nameController.text.trim(),
          'shop_print_name': printNameController.text.trim(),
          'shop_short_name': shortNameController.text.trim(),
        });
        log.success('Admin', 'Shop details updated for "${nameController.text.trim()}"');
        ref.invalidate(shopsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shop details updated successfully!')),
          );
        }
      } catch (e) {
        ref.read(logServiceProvider).error('Admin', 'Failed to update shop details', e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
