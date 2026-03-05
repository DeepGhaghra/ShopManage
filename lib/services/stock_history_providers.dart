import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core_providers.dart';

enum TransactionType { purchase, sale }

class StockHistoryItem {
  final TransactionType type;
  final DateTime date;
  final String partyName;
  final int quantity;
  final String locationName;
  final String? identifier; // Optional invoice no.

  StockHistoryItem({
    required this.type,
    required this.date,
    required this.partyName,
    required this.quantity,
    required this.locationName,
    this.identifier,
  });
}

class StockHistoryRepository {
  final SupabaseClient _client;

  StockHistoryRepository(this._client);

  Future<List<StockHistoryItem>> getDesignHistory(int shopId, int designId) async {
    // 1. Fetch Sales
    final salesRes = await _client
        .from('sales_entries')
        .select('''
          created_at, quantity, invoiceno,
          parties(partyname),
          locations(name)
        ''')
        .eq('shop_id', shopId)
        .eq('design_id', designId);

    // 2. Fetch Purchases
    final purchaseRes = await _client
        .from('purchase')
        .select('''
          date, created_at, quantity,
          parties(partyname)
        ''')
        .eq('shop_id', shopId)
        .eq('design_id', designId);

    final List<StockHistoryItem> history = [];

    // Map Sales
    for (final s in salesRes) {
      final pName = (s['parties'] as Map?)?['partyname'] ?? 'Unknown';
      final lName = (s['locations'] as Map?)?['name'] ?? 'Unknown';
      
      history.add(StockHistoryItem(
        type: TransactionType.sale,
        date: DateTime.parse(s['created_at']),
        partyName: pName,
        quantity: s['quantity'],
        locationName: lName,
        identifier: s['invoiceno'],
      ));
    }

    // Map Purchases
    for (final p in purchaseRes) {
      final pName = (p['parties'] as Map?)?['partyname'] ?? 'Unknown';
      
      // Purchases usually go into a specific location but our DB schema might not 
      // return it directly from the `purchase` table joined view without extra work,
      // (The purchase table doesn't have location_id in the recent view we checked).
      // We will default 'Purchased Stock' or 'Main' if it's not present.
      final dateStr = p['date'] ?? p['created_at']; 
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();

      history.add(StockHistoryItem(
        type: TransactionType.purchase,
        date: date,
        partyName: pName,
        quantity: p['quantity'],
        locationName: 'Entry', // We usually put purchases into stock directly, but the purchase table itself doesn't track location_id directly, the UI does it at insert time based on our review of purchase_providers.dart where location_id is passed but not saved to purchase table itself.
      ));
    }

    // Sort descending by date
    history.sort((a, b) => b.date.compareTo(a.date));

    return history;
  }
}

final stockHistoryRepositoryProvider = Provider<StockHistoryRepository>((ref) {
  return StockHistoryRepository(ref.watch(supabaseClientProvider));
});

final designHistoryProvider = FutureProvider.family<List<StockHistoryItem>, int>((ref, designId) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  
  return ref.watch(stockHistoryRepositoryProvider).getDesignHistory(activeShop.id, designId);
});
