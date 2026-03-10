import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// A stream that emits the currently authenticated user
final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange.map((event) => event.session?.user);
});

// Checks if the current user is the admin
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null || user.email == null) return false;
  return user.email!.toLowerCase().contains('admin');
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

// Provides shops associated with the current admin/user
final associatedShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final allShops = await ref.watch(shopsProvider.future);
  final user = ref.watch(authUserProvider).value;
  
  if (user == null || user.email == null) return [];
  
  final email = user.email!.toLowerCase();
  
  // Super admins or any 'admin' typed email can see all shops
  if (email.contains('admin')) {
    return allShops;
  }
  
  // Filter by domain or keyword for shop-specific users
  // e.g. shiv@shivlaminates.com or somnath@gmail.com
  final parts = email.split('@');
  if (parts.length < 2) return [];
  final local = parts[0];
  final domain = parts[1].split('.')[0];
  
  return allShops.where((shop) {
    final name = shop.shopName.toLowerCase();
    final sName = (shop.shopShortName ?? '').toLowerCase();
    
    // Match local part (somnath@...) or domain (admin@shiv.com)
    return name.contains(local) || sName.contains(local) || 
           (domain != 'gmail' && domain != 'outlook' && domain != 'yahoo' && 
            (name.contains(domain) || sName.contains(domain)));
  }).toList();
});

// Admin providers
final allLocationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(shopRepositoryProvider).getLocations();
});
