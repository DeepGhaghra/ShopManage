import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/folder.dart';
import '../models/folder_distribution.dart';
import '../models/folder_transaction.dart';
import 'core_providers.dart';
import 'log_service.dart';

class FolderDistributionRepository {
  final SupabaseClient _client;
  final LogService _log;

  FolderDistributionRepository(this._client, this._log);

  Future<List<Folder>> getActiveFolders(int shopId) async {
    try {
      final response = await _client
          .from('folders')
          .select()
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .order('folder_name', ascending: true);
      return response.map((json) => Folder.fromJson(json)).toList();
    } catch (e) {
      _log.error('FolderDist', 'Error fetching folders', e);
      return [];
    }
  }

  Future<List<FolderDistribution>> getDistributions(int shopId) async {
    try {
      final response = await _client
          .from('party_folders')
          .select('*, parties(partyname), folders(folder_name)')
          .eq('shop_id', shopId)
          .order('time_added', ascending: false);
      return response.map((json) => FolderDistribution.fromJson(json)).toList();
    } catch (e) {
      _log.error('FolderDist', 'Error fetching distributions', e);
      return [];
    }
  }

  Future<List<FolderTransaction>> getTransactions(
    int shopId, {
    int? partyId,
  }) async {
    try {
      var query = _client
          .from('party_folder_transactions')
          .select('*, parties(partyname), folders(folder_name)')
          .eq('shop_id', shopId);

      if (partyId != null) {
        query = query.eq('party_id', partyId);
      }

      final response = await query.order('time_added', ascending: false);
      return response.map((json) => FolderTransaction.fromJson(json)).toList();
    } catch (e) {
      _log.error('FolderDist', 'Error fetching transactions', e);
      return [];
    }
  }

  Future<void> giveFolder({
    required int shopId,
    required int partyId,
    required int folderId,
    required int currentQuantity,
    int requestedQuantity = 1,
    String? partyName,
    String? folderName,
  }) async {
    try {
      // Fetch current state for business logic (tallying), but remove the hard limit check
      final existingDists = await getDistributions(shopId);
      final currentPartyDist = existingDists
          .where((d) => d.partyId == partyId && d.folderId == folderId)
          .firstOrNull;
      final actualCurrentQty = currentPartyDist?.quantity ?? 0;

      // 1. Update or Insert in party_folders
      final existing = await _client
          .from('party_folders')
          .select()
          .eq('shop_id', shopId)
          .eq('party_id', partyId)
          .eq('folder_id', folderId)
          .maybeSingle();

      if (existing != null) {
        final currentQty = existing['quantity'] as int;
        await _client
            .from('party_folders')
            .update({'quantity': currentQty + requestedQuantity})
            .eq('id', existing['id']);
      } else {
        await _client.from('party_folders').insert({
          'party_id': partyId,
          'folder_id': folderId,
          'quantity': requestedQuantity,
          'shop_id': shopId,
        });
      }

      // 2. Log transaction
      await _client.from('party_folder_transactions').insert({
        'shop_id': shopId,
        'party_id': partyId,
        'folder_id': folderId,
        'transaction_type': 'GIVE',
        'quantity': requestedQuantity,
      });

      final displayName = partyName ?? 'ID $partyId';
      final itemDesc = folderName ?? 'folder(s)';
      _log.success(
        'FolderDist',
        'Gave $requestedQuantity $itemDesc to "$displayName"',
      );
    } catch (e) {
      _log.error('FolderDist', 'Failed to give folder', e);
      rethrow;
    }
  }

  Future<void> returnFolder({
    required int shopId,
    required int partyId,
    required int folderId,
    required int currentQuantity,
    int requestedQuantity = 1,
    String? partyName,
    String? folderName,
  }) async {
    try {
      if (currentQuantity <= 0) {
        throw Exception('No folders to return.');
      }

      // 1. Update party_folders
      final existing = await _client
          .from('party_folders')
          .select()
          .eq('shop_id', shopId)
          .eq('party_id', partyId)
          .eq('folder_id', folderId)
          .single();

      if (existing['quantity'] > requestedQuantity) {
        await _client
            .from('party_folders')
            .update({'quantity': existing['quantity'] - requestedQuantity})
            .eq('id', existing['id']);
      } else {
        await _client.from('party_folders').delete().eq('id', existing['id']);
      }

      // 2. Log transaction
      await _client.from('party_folder_transactions').insert({
        'shop_id': shopId,
        'party_id': partyId,
        'folder_id': folderId,
        'transaction_type': 'RETURN',
        'quantity': -requestedQuantity, // Negative for ledger consistency
      });

      final displayName = partyName ?? 'ID $partyId';
      final itemDesc = folderName ?? 'folder(s)';
      _log.success(
        'FolderDist',
        'Returned $requestedQuantity $itemDesc from "$displayName"',
      );
    } catch (e) {
      _log.error('FolderDist', 'Failed to return folder', e);
      rethrow;
    }
  }
}

final folderDistRepositoryProvider = Provider<FolderDistributionRepository>((
  ref,
) {
  return FolderDistributionRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(logServiceProvider),
  );
});

final activeFoldersProvider = FutureProvider<List<Folder>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  return ref
      .watch(folderDistRepositoryProvider)
      .getActiveFolders(activeShop.id);
});

final folderDistributionsProvider = FutureProvider<List<FolderDistribution>>((
  ref,
) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  return ref
      .watch(folderDistRepositoryProvider)
      .getDistributions(activeShop.id);
});

final folderTransactionsProvider =
    FutureProvider.family<
      List<FolderTransaction>,
      ({int partyId, int? folderId})
    >((ref, args) async {
      final activeShop = ref.watch(activeShopProvider);
      if (activeShop == null) return [];

      final all = await ref
          .watch(folderDistRepositoryProvider)
          .getTransactions(activeShop.id, partyId: args.partyId);

      if (args.folderId != null) {
        return all.where((tx) => tx.folderId == args.folderId).toList();
      }
      return all;
    });
