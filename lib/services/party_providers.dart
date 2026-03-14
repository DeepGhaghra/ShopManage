import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/party.dart';
import 'core_providers.dart';
import 'log_service.dart';

class PartyRepository {
  final SupabaseClient _client;
  final LogService _log;

  PartyRepository(this._client, this._log);

  Future<List<Party>> getParties(int shopId) async {
    try {
      final response = await _client
          .from('parties')
          .select()
          .eq('shop_id', shopId)
          .order('partyname', ascending: true);
      return response.map((json) => Party.fromJson(json)).toList();
    } catch (e) {
      _log.error('Parties', 'Error fetching parties', e);
      return [];
    }
  }

  Future<Party> addParty(Party party) async {
    try {
      final response = await _client
          .from('parties')
          .insert(party.toJson(excludeId: true))
          .select()
          .single();
      return Party.fromJson(response);
    } catch (e) {
      _log.error('Parties', 'Failed to add party "${party.partyName}"', e);
      rethrow;
    }
  }

  Future<void> updateParty(Party party) async {
    try {
      await _client
          .from('parties')
          .update(party.toJson(excludeId: true))
          .eq('id', party.id);
    } catch (e) {
      _log.error('Parties', 'Failed to update party "${party.partyName}"', e);
      rethrow;
    }
  }

  Future<void> deleteParty(int id) async {
    try {
      await _client.from('parties').delete().eq('id', id);
    } catch (e) {
      _log.error('Parties', 'Failed to delete party ID $id', e);
      rethrow;
    }
  }
}

final partyRepositoryProvider = Provider<PartyRepository>((ref) {
  return PartyRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(logServiceProvider),
  );
});

// Provides parties for the currently active shop
final partiesProvider = FutureProvider<List<Party>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  
  return ref.watch(partyRepositoryProvider).getParties(activeShop.id);
});
