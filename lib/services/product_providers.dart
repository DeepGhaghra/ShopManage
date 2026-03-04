import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_head.dart';
import '../models/products_design.dart';
import 'core_providers.dart';

class ProductRepository {
  final SupabaseClient _client;

  ProductRepository(this._client);

  Future<List<ProductHead>> getActiveProductHeads(int shopId) async {
    final response = await _client
        .from('product_head')
        .select('*, folders!inner(folder_name, is_active)')
        .eq('shop_id', shopId)
        .eq('folders.is_active', true)
        .order('product_name', ascending: true);
    return response.map((json) => ProductHead.fromJson(json)).toList();
  }

  Future<List<ProductsDesign>> getProductDesigns(int shopId, int productHeadId) async {
    final response = await _client
        .from('products_design')
        .select()
        .eq('shop_id', shopId)
        .eq('product_head_id', productHeadId)
        .order('design_no', ascending: true);
    return response.map((json) => ProductsDesign.fromJson(json)).toList();
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(supabaseClientProvider));
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
