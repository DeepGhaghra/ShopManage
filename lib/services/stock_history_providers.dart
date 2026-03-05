import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core_providers.dart';

enum TransactionType { purchase, sale, transferIn, transferOut, manualAdd, adjustment }

class StockHistoryItem {
  final TransactionType type;
  final DateTime date;
  final String partyName; // Or fallback 'Internal Transfer'
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
    // 1. Fetch exact timeline from stock_transactions, EXCLUDING sale_edit_reverse
    final transactionsRes = await _client
        .from('stock_transactions')
        .select('''
          id, quantity, transaction_type, reference_id, created_at,
          locations(name)
        ''')
        .eq('shop_id', shopId)
        .eq('design_id', designId)
        .neq('transaction_type', 'sale_edit_reverse')
        .order('created_at', ascending: false);

    final List<StockHistoryItem> history = [];
    final List<int> purchaseRefIds = [];
    final List<int> saleRefIds = [];

    // Collect reference IDs to fetch party names efficiently
    for (final t in transactionsRes) {
      if (t['transaction_type'] == 'purchase' && t['reference_id'] != null) {
        purchaseRefIds.add(t['reference_id']);
      } else if (t['transaction_type'] == 'sale' && t['reference_id'] != null) {
        saleRefIds.add(t['reference_id']);
      }
    }

    // 2. Fetch party names for purchases and sales in bulk queries
    final Map<int, String> purchaseParties = {};
    if (purchaseRefIds.isNotEmpty) {
      final pRes = await _client
          .from('purchase')
          .select('id, parties(partyname)')
          .inFilter('id', purchaseRefIds);
      for (final p in pRes) {
        purchaseParties[p['id']] = (p['parties'] as Map?)?['partyname'] ?? 'Unknown Supplier';
      }
    }

    final Map<int, String> saleParties = {};
    final Map<int, String> saleInvoices = {};
    final Set<int> validSaleIds = {};
    if (saleRefIds.isNotEmpty) {
      final sRes = await _client
          .from('sales_entries')
          .select('id, invoiceno, parties(partyname)')
          .inFilter('id', saleRefIds);
      for (final s in sRes) {
        validSaleIds.add(s['id']);
        saleParties[s['id']] = (s['parties'] as Map?)?['partyname'] ?? 'Unknown Buyer';
        saleInvoices[s['id']] = s['invoiceno'] as String;
      }
    }

    // 3. Map into History Items
    for (final t in transactionsRes) {
      final rawType = t['transaction_type'] as String;
      final quantity = t['quantity'] as int;
      final refId = t['reference_id'] as int?;
      final lName = (t['locations'] as Map?)?['name'] ?? 'Unknown Location';
      final date = DateTime.parse(t['created_at']);

      TransactionType mappedType;
      String partyName = '';
      String? invoice;

      if (rawType == 'purchase') {
        mappedType = TransactionType.purchase;
        partyName = refId != null ? (purchaseParties[refId] ?? 'Unknown Supplier') : 'Unknown Supplier';
      } else if (rawType == 'sale') {
        // If the sales_entry was deleted (ghost sale), skip it
        if (refId != null && !validSaleIds.contains(refId)) {
          continue; 
        }
        mappedType = TransactionType.sale;
        partyName = refId != null ? (saleParties[refId] ?? 'Unknown Buyer') : 'Legacy Sale';
        invoice = refId != null ? saleInvoices[refId] : null;
      } else if (rawType == 'transfer') {
        mappedType = quantity > 0 ? TransactionType.transferIn : TransactionType.transferOut;
        partyName = 'Location Transfer';
      } else if (rawType == 'new') {
        mappedType = TransactionType.manualAdd;
        partyName = 'Manual Stock Add';
      } else {
        mappedType = quantity >= 0 ? TransactionType.manualAdd : TransactionType.adjustment;
        partyName = rawType.toUpperCase();
      }

      history.add(StockHistoryItem(
        type: mappedType,
        date: date,
        partyName: partyName,
        quantity: quantity,
        locationName: lName,
        identifier: invoice,
      ));
    }

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
