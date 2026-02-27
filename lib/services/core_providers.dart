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
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(ref.watch(supabaseClientProvider));
});

// Provides all available shops
final shopsProvider = FutureProvider<List<Shop>>((ref) async {
  return ref.watch(shopRepositoryProvider).getShops();
});
