import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stock.dart';
import 'core_providers.dart';

class StockRepository {
  final SupabaseClient _client;

  StockRepository(this._client);

  Future<List<Stock>> getStockByShop(int shopId) async {
    final response = await _client
        .from('stock')
        .select('''
          *,
          products_design (design_no, product_head (product_name)),
          locations (name)
        ''')
        .eq('shop_id', shopId)
        .order('quantity', ascending: true);
        
    // Mapping the joined data into the Stock model and injecting design_no / location_name
    return response.map((json) {
       final stock = Stock.fromJson(json);
       // We can attach the joined data dynamically if we update the Stock model, 
       // but for simplicity let's return as is and handle in UI or update model.
       return stock;
    }).toList();
  }
  Future<void> addStock({
    required int shopId,
    required String designNo,
    required int productHeadId,
    required int locationId,
    required int quantity,
  }) async {
    await _client.rpc('add_stock_v2', params: {
      'p_shop_id': shopId,
      'p_design_no': designNo,
      'p_product_head_id': productHeadId,
      'p_location_id': locationId,
      'p_quantity': quantity,
    });
  }

  Future<List<Map<String, dynamic>>> getAvailableLocationsForDesign(int shopId, int designId) async {
    final response = await _client
        .from('stock')
        .select('''
          id, quantity,
          locations (id, name)
        ''')
        .eq('shop_id', shopId)
        .eq('design_id', designId)
        .gt('quantity', 0)
        .order('quantity', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> transferStock({
    required int shopId,
    required int designId,
    required int fromLocationId,
    required int toLocationId,
    required int quantity,
  }) async {
    await _client.rpc('transfer_stock_v2', params: {
      'p_shop_id': shopId,
      'p_design_id': designId,
      'p_from_location_id': fromLocationId,
      'p_to_location_id': toLocationId,
      'p_quantity': quantity,
    });
  }
}

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(ref.watch(supabaseClientProvider));
});

final shopStockProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  
  final response = await ref.watch(supabaseClientProvider)
        .from('stock')
        .select('''
          id, quantity,
          products_design (id, design_no, product_head_id, product_head (id, product_name, product_rate, folders (folder_name))),
          locations (id, name)
        ''')
        .eq('shop_id', activeShop.id)
        .gt('quantity', 0)                          // only show items with stock
        .order('quantity', ascending: false);        // highest stock first
        
  final data = List<Map<String, dynamic>>.from(response);
  for (var r in data) {
    Map<String, dynamic>? getData(dynamic d) {
      if (d == null) return null;
      if (d is List) return d.isEmpty ? null : d.first as Map<String, dynamic>;
      if (d is Map) return d as Map<String, dynamic>;
      return null;
    }

    final pd = getData(r['products_design']);
    final loc = getData(r['locations']);
    
    // Normalize the record with the extracted maps
    r['products_design'] = pd;
    r['locations'] = loc;
    
    final d = (pd?['design_no'] as String? ?? '').toLowerCase();
    final l = (loc?['name'] as String? ?? '').toLowerCase();
    r['search_key'] = '$d $l';
  }
  return data;
});

final locationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];

  final response = await ref.watch(supabaseClientProvider)
      .from('locations')
      .select()
      .eq('shop_id', activeShop.id)
      .order('name', ascending: true);
      
  return List<Map<String, dynamic>>.from(response);
});

final designsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];

  final response = await ref.watch(supabaseClientProvider)
      .from('products_design')
      .select('id, design_no, product_head (product_name)')
      .eq('shop_id', activeShop.id)
      .order('design_no');
  
  return List<Map<String, dynamic>>.from(response);
});

final sortedDesignsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final designsAsync = ref.watch(designsProvider);
  return designsAsync.whenData((list) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) => (a['design_no'] as String).toUpperCase().compareTo((b['design_no'] as String).toUpperCase()));
    return sorted;
  });
});
