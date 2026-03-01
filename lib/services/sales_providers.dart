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
          'location_id': entry.locationId, // Fix: Use location_id from entry, not stockRes['id']
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
        .select('*, parties(partyname)')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .limit(200); // Increased limit as we'll be merging these locally
    return response.map((json) => SalesEntry.fromJson(json)).toList();
  }

  Future<void> updateSalesInvoice(String invoiceNo, List<SalesEntry> newEntries) async {
    // 1. Fetch old entries
    final oldData = await _client.from('sales_entries').select().eq('invoiceno', invoiceNo).eq('shop_id', newEntries.first.shopId);
    final oldEntries = oldData.map((e) => SalesEntry.fromJson(e)).toList();

    // 2. Reverse old stock deductions
    for (final oldEntry in oldEntries) {
      final stockRes = await _client
          .from('stock')
          .select('id, quantity')
          .eq('shop_id', oldEntry.shopId)
          .eq('design_id', oldEntry.designId)
          .eq('location_id', oldEntry.locationId)
          .maybeSingle();

      if (stockRes != null) {
        final currentQty = stockRes['quantity'] as int;
        final newQty = currentQty + oldEntry.quantity; // ADD BACK
        await _client.from('stock').update({'quantity': newQty}).eq('id', stockRes['id']);

        // Log transaction
        await _client.from('stock_transactions').insert({
          'design_id': oldEntry.designId,
          'location_id': oldEntry.locationId, // Fix: Use location_id from entry, not stockRes['id']
          'quantity': oldEntry.quantity, // POSITIVE
          'transaction_type': 'sale_edit_reverse',
          'shop_id': oldEntry.shopId,
        });
      }
    }

    // 3. Delete old entries
    await _client.from('sales_entries').delete().eq('invoiceno', invoiceNo).eq('shop_id', newEntries.first.shopId);

    // 4. Save new entries (this deducts the new stock)
    await saveSalesInvoice(newEntries);
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
