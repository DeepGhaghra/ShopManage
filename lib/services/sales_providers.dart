import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sales_entry.dart';
import '../models/pricelist.dart';
import 'core_providers.dart';
import 'log_service.dart';

class SalesRepository {
  final SupabaseClient _client;
  final LogService _log;

  SalesRepository(this._client, this._log);

  Future<String> generateInvoiceNo(int shopId) async {
    try {
      final response = await _client.rpc('generate_sales_invoice_no', params: {'p_shop_id': shopId});
      return response as String;
    } catch (e) {
      _log.error('Sales', 'Error generating invoice number', e);
      rethrow;
    }
  }

  Future<void> saveSalesInvoice(List<SalesEntry> entries) async {
    if (entries.isEmpty) return;
    
    final first = entries.first;
    try {
      final items = entries.map((e) => {
        'design_id': e.designId,
        'location_id': e.locationId,
        'product_id': e.productId,
        'quantity': e.quantity,
        'rate': e.rate,
        'amount': e.amount,
      }).toList();

      await _client.rpc('save_sales_invoice_v2', params: {
        'p_shop_id': first.shopId,
        'p_invoice_no': first.invoiceno,
        'p_party_id': first.partyId,
        'p_items': items,
        'p_date': "${first.date.year}-${first.date.month.toString().padLeft(2, '0')}-${first.date.day.toString().padLeft(2, '0')}",
      });
      _log.success('Sales', 'Invoice ${first.invoiceno} saved for shop ID ${first.shopId}');
    } catch (e) {
      _log.error('Sales', 'Failed to save sales invoice ${first.invoiceno}', e);
      rethrow;
    }
  }

  Future<List<SalesEntry>> getRecentSales(int shopId) async {
    try {
      final response = await _client
          .from('sales_entries')
          .select('''
            *, 
            parties(partyname),
            products_design(
              design_no, 
              product_head(
                product_name, 
                folders(folder_name)
              )
            ),
            locations(name)
          ''')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(200);
      return response.map((json) => SalesEntry.fromJson(json)).toList();
    } catch (e) {
      _log.error('Sales', 'Error fetching recent sales', e);
      return [];
    }
  }

  Future<void> updateSalesInvoice(String oldInvoiceNo, List<SalesEntry> newEntries) async {
    if (newEntries.isEmpty) return;

    final first = newEntries.first;
    try {
      final items = newEntries.map((e) => {
        'design_id': e.designId,
        'location_id': e.locationId,
        'product_id': e.productId,
        'quantity': e.quantity,
        'rate': e.rate,
        'amount': e.amount,
      }).toList();

      await _client.rpc('update_sales_invoice_v2', params: {
        'p_shop_id': first.shopId,
        'p_old_invoice_no': oldInvoiceNo,
        'p_new_invoice_no': first.invoiceno,
        'p_party_id': first.partyId,
        'p_new_items': items,
        'p_date': "${first.date.year}-${first.date.month.toString().padLeft(2, '0')}-${first.date.day.toString().padLeft(2, '0')}",
      });
      _log.success('Sales', 'Invoice $oldInvoiceNo updated to ${first.invoiceno}');
    } catch (e) {
      _log.error('Sales', 'Failed to update invoice $oldInvoiceNo', e);
      rethrow;
    }
  }

  Future<int?> getPartyProductRate(int shopId, int partyId, int productId) async {
    try {
      final response = await _client
          .from('pricelist')
          .select('price')
          .eq('shop_id', shopId)
          .eq('party_id', partyId)
          .eq('product_id', productId)
          .maybeSingle();
      
      if (response == null) return null;
      return response['price'] as int;
    } catch (e) {
      _log.error('Sales', 'Error fetching party product rate', e);
      return null;
    }
  }

  Future<void> upsertPricelist(Pricelist pricelist) async {
    try {
      await _client.from('pricelist').upsert(
        pricelist.toJson(),
        onConflict: 'product_id, party_id',
      );
    } catch (e) {
      _log.error('Sales', 'Failed to upsert pricelist entry', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPricelist(int shopId) async {
    try {
      final res = await _client
          .from('pricelist')
          .select('''
            id, price, modified_at, product_id,
            parties(partyname),
            product_head(product_name, folders(folder_name))
          ''')
          .eq('shop_id', shopId)
          .order('modified_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      _log.error('Sales', 'Error fetching pricelist', e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPricelistForParty(int shopId, int partyId) async {
    try {
      final res = await _client
          .from('pricelist')
          .select('product_id, price')
          .eq('shop_id', shopId)
          .eq('party_id', partyId);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      _log.error('Sales', 'Error fetching pricelist for party ID $partyId', e);
      return [];
    }
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(logServiceProvider),
  );
});

final recentSalesProvider = FutureProvider<List<SalesEntry>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  return ref.watch(salesRepositoryProvider).getRecentSales(activeShop.id);
});

/// Optimized provider that groups sales by invoice number to prevent heavy UI logic
final groupedRecentSalesProvider = Provider<AsyncValue<Map<String, List<SalesEntry>>>>((ref) {
  final recentSalesAsync = ref.watch(recentSalesProvider);
  return recentSalesAsync.whenData((sales) {
    final grouped = <String, List<SalesEntry>>{};
    for (var sale in sales) {
      grouped.putIfAbsent(sale.invoiceno, () => []).add(sale);
    }
    return grouped;
  });
});

final pricelistProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  return ref.watch(salesRepositoryProvider).getPricelist(activeShop.id);
});
