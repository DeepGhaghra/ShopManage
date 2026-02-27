import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/party.dart';
import 'core_providers.dart';

class PartyRepository {
  final SupabaseClient _client;

  PartyRepository(this._client);

  Future<List<Party>> getParties(int shopId) async {
    final response = await _client
        .from('parties')
        .select()
        .eq('shop_id', shopId)
        .order('partyname', ascending: true);
    return response.map((json) => Party.fromJson(json)).toList();
  }

  Future<Party> addParty(Party party) async {
    final response = await _client
        .from('parties')
        .insert(party.toJson(excludeId: true))
        .select()
        .single();
    return Party.fromJson(response);
  }

  Future<void> updateParty(Party party) async {
    await _client
        .from('parties')
        .update(party.toJson(excludeId: true))
        .eq('id', party.id);
  }

  Future<void> deleteParty(int id) async {
    await _client.from('parties').delete().eq('id', id);
  }
}

final partyRepositoryProvider = Provider<PartyRepository>((ref) {
  return PartyRepository(ref.watch(supabaseClientProvider));
});

// Provides parties for the currently active shop
final partiesProvider = FutureProvider<List<Party>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  
  return ref.watch(partyRepositoryProvider).getParties(activeShop.id);
});
