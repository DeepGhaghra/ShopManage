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
    // 1. Get or create design ID (unique constraint is on design_no per shop)
    int designId;
    final designResponse = await _client
        .from('products_design')
        .select('id')
        .eq('shop_id', shopId)
        .eq('design_no', designNo)
        .maybeSingle();

    if (designResponse != null) {
      designId = designResponse['id'] as int;
    } else {
      final insertResponse = await _client.from('products_design').insert({
        'shop_id': shopId,
        'design_no': designNo,
        'product_head_id': productHeadId,
        'time_added': DateTime.now().toIso8601String(),
      }).select('id').single();
      designId = insertResponse['id'] as int;
    }

    // 2. Check if stock record already exists for this design, location, and shop
    final existingRecords = await _client
        .from('stock')
        .select()
        .eq('shop_id', shopId)
        .eq('design_id', designId)
        .eq('location_id', locationId)
        .maybeSingle();

    if (existingRecords != null) {
      // Update existing record by incrementing quantity
      final currentQty = existingRecords['quantity'] as int;
      await _client
          .from('stock')
          .update({
            'quantity': currentQty + quantity, 
            'modified_at': DateTime.now().toIso8601String()
          })
          .eq('id', existingRecords['id']);
    } else {
      // Insert new record
      await _client.from('stock').insert({
        'shop_id': shopId,
        'design_id': designId,
        'location_id': locationId,
        'quantity': quantity,
        'time_added': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
      });
    }

    // 3. Log the transaction as 'new'
    await _client.from('stock_transactions').insert({
      'shop_id': shopId,
      'design_id': designId,
      'location_id': locationId,
      'quantity': quantity,
      'transaction_type': 'new',
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
    if (fromLocationId == toLocationId) throw Exception('Cannot transfer to the same location');

    // 1. Check source stock
    final sourceStock = await _client
        .from('stock')
        .select()
        .eq('shop_id', shopId)
        .eq('design_id', designId)
        .eq('location_id', fromLocationId)
        .single();
    
    final currentSourceQty = sourceStock['quantity'] as int;
    if (currentSourceQty < quantity) {
      throw Exception('Insufficient stock in source location.');
    }

    // 2. Decrement source stock
    await _client.from('stock').update({
      'quantity': currentSourceQty - quantity,
      'modified_at': DateTime.now().toIso8601String(),
    }).eq('id', sourceStock['id']);

    // 3. Increment or insert destination stock
    final targetStock = await _client
        .from('stock')
        .select()
        .eq('shop_id', shopId)
        .eq('design_id', designId)
        .eq('location_id', toLocationId)
        .maybeSingle();

    if (targetStock != null) {
      await _client.from('stock').update({
        'quantity': (targetStock['quantity'] as int) + quantity,
        'modified_at': DateTime.now().toIso8601String(),
      }).eq('id', targetStock['id']);
    } else {
      await _client.from('stock').insert({
        'shop_id': shopId,
        'design_id': designId,
        'location_id': toLocationId,
        'quantity': quantity,
        'time_added': DateTime.now().toIso8601String(),
        'modified_at': DateTime.now().toIso8601String(),
      });
    }

    // 4. Log the transfer record
    await _client.from('stock_transfers').insert({
      'shop_id': shopId,
      'design_id': designId,
      'from_location_id': fromLocationId,
      'to_location_id': toLocationId,
      'quantity': quantity,
    });

    // 5. Log both transactions into stock_transactions (Out & In)
    await _client.from('stock_transactions').insert([
      {
        'shop_id': shopId,
        'design_id': designId,
        'location_id': fromLocationId,
        'quantity': -quantity, // Deducted
        'transaction_type': 'transfer',
      },
      {
        'shop_id': shopId,
        'design_id': designId,
        'location_id': toLocationId,
        'quantity': quantity, // Added
        'transaction_type': 'transfer',
      }
    ]);
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
          products_design (id, design_no, product_head_id, product_head (id, product_name, product_rate)),
          locations (id, name)
        ''')
        .eq('shop_id', activeShop.id)
        .gt('quantity', 0)                          // only show items with stock
        .order('quantity', ascending: false);        // highest stock first
        
  return List<Map<String, dynamic>>.from(response);
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
