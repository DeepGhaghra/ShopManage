import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_head.dart';
import '../models/products_design.dart';
import 'core_providers.dart';

import '../services/log_service.dart';

class ProductRepository {
  final SupabaseClient _client;
  final LogService _log;

  ProductRepository(this._client, this._log);

  Future<List<ProductHead>> getActiveProductHeads(int shopId) async {
    try {
      final response = await _client
          .from('product_head')
          .select('*, folders!inner(folder_name, is_active)')
          .eq('shop_id', shopId)
          .eq('folders.is_active', true)
          .order('product_name', ascending: true);
      return response.map((json) => ProductHead.fromJson(json)).toList();
    } catch (e) {
      _log.error('Products', 'Error fetching active product heads', e);
      return [];
    }
  }

  Future<List<ProductsDesign>> getProductDesigns(int shopId, int productHeadId) async {
    try {
      final response = await _client
          .from('products_design')
          .select()
          .eq('shop_id', shopId)
          .eq('product_head_id', productHeadId)
          .order('design_no', ascending: true);
      return response.map((json) => ProductsDesign.fromJson(json)).toList();
    } catch (e) {
      _log.error('Products', 'Error fetching product designs', e);
      return [];
    }
  }

  // Admin Folder Management
  Future<List<Map<String, dynamic>>> getFolders() async {
    try {
      return await _client
          .from('folders')
          .select('*, shop(shop_name)')
          .order('folder_name', ascending: true);
    } catch (e) {
      _log.error('Admin', 'Error fetching folders', e);
      return [];
    }
  }

  Future<void> createFolder(String name, int shopId) async {
    try {
      await _client.from('folders').insert({
        'folder_name': name,
        'is_active': true,
        'shop_id': shopId,
      });
      _log.success('Admin', 'Folder "$name" created for shop ID $shopId');
    } catch (e) {
      _log.error('Admin', 'Failed to create folder "$name"', e);
      rethrow;
    }
  }

  Future<void> updateFolder(int id, String name, bool isActive) async {
    try {
      await _client.from('folders').update({'folder_name': name, 'is_active': isActive}).eq('id', id);
      _log.success('Admin', 'Folder "$name" updated (active: $isActive)');
    } catch (e) {
      _log.error('Admin', 'Failed to update folder "$name"', e);
      rethrow;
    }
  }

  // Admin Product Head Management
  Future<List<Map<String, dynamic>>> getAllProductHeads() async {
    try {
      return await _client
          .from('product_head')
          .select('*, folders(folder_name), shop(shop_name)')
          .order('product_name', ascending: true);
    } catch (e) {
      _log.error('Admin', 'Error fetching all product heads', e);
      return [];
    }
  }

  Future<void> createProductHead({
    required String name,
    required int rate,
    required int folderId,
    required int shopId,
  }) async {
    try {
      await _client.from('product_head').insert({
        'product_name': name,
        'product_rate': rate,
        'folder_id': folderId,
        'shop_id': shopId,
      });
      _log.success('Admin', 'Product Head "$name" created');
    } catch (e) {
      _log.error('Admin', 'Failed to create product head "$name"', e);
      rethrow;
    }
  }

  Future<void> updateProductHead({
    required int id,
    required String name,
    required int rate,
    required int folderId,
  }) async {
    try {
      await _client.from('product_head').update({
        'product_name': name,
        'product_rate': rate,
        'folder_id': folderId,
      }).eq('id', id);
      _log.success('Admin', 'Product Head "$name" updated');
    } catch (e) {
      _log.error('Admin', 'Failed to update product head "$name"', e);
      rethrow;
    }
  }

  Future<void> batchBulkUpdateProducts({
    required List<Map<String, int>> adjustments,
    required int shopId,
    required bool applyToParties,
  }) async {
    try {
      await _client.rpc('batch_bulk_update_products', params: {
        'p_adjustments': adjustments,
        'p_shop_id': shopId,
        'p_apply_to_parties': applyToParties,
      });
      _log.success('Admin', 'Batch bulk update completed for ${adjustments.length} products');
    } catch (e) {
      _log.error('Admin', 'Batch bulk update failed', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getProductRateHistory(int productId, int shopId) async {
    try {
      return await _client
          .from('product_rate_history')
          .select()
          .eq('product_id', productId)
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);
    } catch (e) {
      _log.error('Admin', 'Error fetching product rate history', e);
      return [];
    }
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(logServiceProvider),
  );
});

// Provides product heads for the active shop
final productHeadsProvider = FutureProvider<List<ProductHead>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  return ref.watch(productRepositoryProvider).getActiveProductHeads(activeShop.id);
});

// Family to provide designs for a given product head
final productDesignsProvider = FutureProvider.family<List<ProductsDesign>, int>((ref, productHeadId) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  return ref.watch(productRepositoryProvider).getProductDesigns(activeShop.id, productHeadId);
});

// Admin providers
final allFoldersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(productRepositoryProvider).getFolders();
});

final allProductHeadsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(productRepositoryProvider).getAllProductHeads();
});

// Provides the rate history for a specific product head
final productRateHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, productId) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  return ref.watch(productRepositoryProvider).getProductRateHistory(productId, activeShop.id);
});
