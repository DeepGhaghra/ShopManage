import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sales_entry.dart';
import 'core_providers.dart';

class SalesRepository {
  final SupabaseClient _client;

  SalesRepository(this._client);

  Future<String> generateInvoiceNo(int shopId) async {
    final response = await _client.rpc('generate_sales_invoice_no', params: {'p_shop_id': shopId});
    return response as String;
  }

  Future<void> saveSalesInvoice(List<SalesEntry> entries) async {
    // 1. Insert Sales Entries
    final insertData = entries.map((e) => e.toJson(excludeId: true)).toList();
    await _client.from('sales_entries').insert(insertData);

    // 2. Deduct Stock from specific locations
    for (final entry in entries) {
      final stockRes = await _client
          .from('stock')
          .select('id, quantity')
          .eq('shop_id', entry.shopId)
          .eq('design_id', entry.designId)
          .eq('location_id', entry.locationId)
          .maybeSingle();

      if (stockRes != null) {
        final currentQty = stockRes['quantity'] as int;
        final newQty = currentQty - entry.quantity;
        
        await _client.from('stock').update({'quantity': newQty}).eq('id', stockRes['id']);

        // Log transaction
        await _client.from('stock_transactions').insert({
          'design_id': entry.designId,
          'location_id': stockRes['id'],
          'quantity': -entry.quantity,
          'transaction_type': 'sale',
          'shop_id': entry.shopId,
        });
      } else {
        throw Exception("Stock not found for design ${entry.designId} at location ${entry.locationId}");
      }
    }
  }

  Future<List<SalesEntry>> getRecentSales(int shopId) async {
    final response = await _client
        .from('sales_entries')
        .select()
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .limit(50);
    return response.map((json) => SalesEntry.fromJson(json)).toList();
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(supabaseClientProvider));
});

final recentSalesProvider = FutureProvider<List<SalesEntry>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  return ref.watch(salesRepositoryProvider).getRecentSales(activeShop.id);
});
