import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// A stream that emits the currently authenticated user session
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final authUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value?.session?.user;
});

// Fetches the user profile from the database
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authUserProvider);
  if (user == null) return null;
  
  final response = await ref.watch(supabaseClientProvider)
      .from('users')
      .select()
      .eq('id', user.id)
      .maybeSingle();
  return response;
});

// Checks if the current user is an admin based on database role
final isAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  if (profile == null) {
    // Fallback to email during initial load or if profile fetch fails
    final user = ref.watch(authUserProvider);
    return user?.email?.toLowerCase().contains('admin') ?? false;
  }
  return profile['role']?.toString().toLowerCase() == 'admin';
});

class ActiveShopNotifier extends Notifier<Shop?> {
  @override
  Shop? build() => null;
  void setShop(Shop? shop) => state = shop;
}

final activeShopProvider = NotifierProvider<ActiveShopNotifier, Shop?>(() {
  return ActiveShopNotifier();
});

class ShopRepository {
  final SupabaseClient _client;

  ShopRepository(this._client);

  Future<List<Shop>> getShops() async {
    final response = await _client.from('shop').select().order('id', ascending: true);
    return response.map((json) => Shop.fromJson(json)).toList();
  }

  // Admin Location Management
  Future<List<Map<String, dynamic>>> getLocations() async {
    return await _client.from('locations').select('*, shop!inner(shop_name)').order('id', ascending: true);
  }

  Future<void> createLocation(String name, int shopId) async {
    await _client.from('locations').insert({'name': name, 'shop_id': shopId});
  }

  Future<void> updateLocation(int id, String name) async {
    await _client.from('locations').update({'name': name}).eq('id', id);
  }

  Future<void> updateShop(int id, Map<String, dynamic> data) async {
    await _client.from('shop').update(data).eq('id', id);
  }
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(ref.watch(supabaseClientProvider));
});

// Provides all available shops
final shopsProvider = FutureProvider<List<Shop>>((ref) async {
  return ref.watch(shopRepositoryProvider).getShops();
});

// Provides shops associated with the current admin/user via user_shop_access table
final associatedShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final user = ref.watch(authUserProvider);
  if (user == null) return [];

  final isAdmin = ref.watch(isAdminProvider);
  final allShops = await ref.watch(shopsProvider.future);

  // Admins see all shops
  if (isAdmin) {
    return allShops;
  }

  // Regular users see only assigned shops from user_shop_access
  final response = await ref.watch(supabaseClientProvider)
      .from('user_shop_access')
      .select('shop_id')
      .eq('user_id', user.id);
  
  final List<int> assignedIds = (response as List).map((row) => row['shop_id'] as int).toList();
  
  return allShops.where((shop) => assignedIds.contains(shop.id)).toList();
});

// Admin providers
final allLocationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopRepositoryProvider).getLocations();
});
