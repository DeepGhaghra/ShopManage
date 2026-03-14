import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core_providers.dart';
import 'log_service.dart';
import '../utils/date_utils.dart';

// ─── Single purchase line (shared between manual + bulk) ──────────────────────
class PurchaseLine {
  final String designNo;
  final int    designId;
  final int    locationId;
  final int    quantity;

  const PurchaseLine({
    required this.designNo,
    required this.designId,
    required this.locationId,
    required this.quantity,
  });
}

// ─── Repository ───────────────────────────────────────────────────────────────
class PurchaseRepository {
  final SupabaseClient _client;
  final LogService _log;

  PurchaseRepository(this._client, this._log);

  Future<void> addPurchase({
    required int shopId,
    required String date,
    required int partyId,
    required int designId,
    required int quantity,
    required int locationId,
  }) async {
    try {
      // 1. Insert Purchase Record
      final purchaseResponse = await _client
          .from('purchase')
          .insert({
            'shop_id':   shopId,
            'date':      date,
            'party_id':  partyId,
            'design_id': designId,
            'quantity':  quantity,
          })
          .select()
          .single();

      final purchaseId = purchaseResponse['id'] as int;

      // 2. Increment Stock (upsert-style)
      final stockRes = await _client
          .from('stock')
          .select('id, quantity')
          .eq('shop_id',     shopId)
          .eq('design_id',   designId)
          .eq('location_id', locationId)
          .maybeSingle();

      if (stockRes != null) {
        final newQty = (stockRes['quantity'] as int) + quantity;
        await _client.from('stock').update({
          'quantity':    newQty,
          'modified_at': DateTime.now().toIST().toIso8601String(),
        }).eq('id', stockRes['id']);
      } else {
        await _client.from('stock').insert({
          'shop_id':     shopId,
          'design_id':   designId,
          'location_id': locationId,
          'quantity':    quantity,
          'modified_at': DateTime.now().toIST().toIso8601String(),
        });
      }

      // 3. Log Stock Transaction
      await _client.from('stock_transactions').insert({
        'shop_id':          shopId,
        'design_id':        designId,
        'location_id':      locationId,
        'quantity':         quantity,
        'transaction_type': 'purchase',
        'reference_id':     purchaseId,
      });
      
      _log.success('Purchase', 'Purchase added for design ID $designId (Qty: $quantity)');
    } catch (e) {
      _log.error('Purchase', 'Failed to add purchase for design ID $designId', e);
      rethrow;
    }
  }

  /// Saves multiple purchase lines sequentially to prevent race conditions
  /// on stock quantity updates for the same design+location combination.
  Future<void> saveBulkPurchase({
    required int shopId,
    required int partyId,
    required String date,
    required List<PurchaseLine> lines,
  }) async {
    try {
      for (final line in lines) {
        await addPurchase(
          shopId:     shopId,
          date:       date,
          partyId:    partyId,
          designId:   line.designId,
          quantity:   line.quantity,
          locationId: line.locationId,
        );
      }
      _log.success('Purchase', 'Bulk purchase completed: ${lines.length} lines saved');
    } catch (e) {
      _log.error('Purchase', 'Bulk purchase failed after saving some/none of ${lines.length} lines', e);
      rethrow;
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────
final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(logServiceProvider),
  );
});

/// Recent purchases for the active shop (last 50)
final recentPurchasesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];

  try {
    final response = await ref.watch(supabaseClientProvider)
        .from('purchase')
        .select('''
          id, date, quantity,
          parties (partyname),
          products_design (design_no)
        ''')
        .eq('shop_id', activeShop.id)
        .order('id', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    ref.read(logServiceProvider).error('Purchase', 'Error fetching recent purchases', e);
    return [];
  }
});
