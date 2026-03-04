import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core_providers.dart';

final dashboardMetricsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return {};

  final client = ref.watch(supabaseClientProvider);
  
  // 1. Today's Total Sales Quantity
  final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0).toUtc().toIso8601String();
  final salesResponse = await client
      .from('sales_entries')
      .select('quantity')
      .eq('shop_id', activeShop.id)
      .gte('created_at', todayStart);
  
  final todaySalesQty = salesResponse.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));

  // 2. Low Stock Items (Qty < 3)
  final lowStockResponse = await client
      .from('stock')
      .select('id')
      .eq('shop_id', activeShop.id)
      .lt('quantity', 3);
      
  final lowStockCount = lowStockResponse.length;

  // 3. Trending Stock Qty (Highest selling design in last 30 days)
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toUtc().toIso8601String();
  final trendingResponse = await client
      .from('sales_entries')
      .select('quantity, design_id')
      .eq('shop_id', activeShop.id)
      .gte('created_at', thirtyDaysAgo);

  // Group by design_id and sum quantity
  final designStats = <int, int>{};
  for (final item in trendingResponse) {
    final designId = item['design_id'] as int;
    final qty = item['quantity'] as int;
    designStats[designId] = (designStats[designId] ?? 0) + qty;
  }

  // Find the highest volume design
  int maxVolume = 0;
  if (designStats.isNotEmpty) {
    maxVolume = designStats.values.reduce((a, b) => a > b ? a : b);
  }

  return {
    'todaySalesQty': todaySalesQty,
    'lowStockCount': lowStockCount,
    'trendingMaxQty': maxVolume,
  };
});

final dashboardDetailProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, type) async {
  final activeShop = ref.watch(activeShopProvider);
  if (activeShop == null) return [];
  
  final client = ref.watch(supabaseClientProvider);
  final shopId = activeShop.id;

  switch (type) {
    case 'today_sales':
      final today = DateTime.now().copyWith(hour: 0, minute: 0, second: 0).toUtc().toIso8601String();
      final res = await client
          .from('sales_entries')
          .select('quantity, created_at, parties!inner(partyname), products_design!inner(design_no)')
          .eq('shop_id', shopId)
          .gte('created_at', today)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    
    case 'low_stock':
      final res = await client
          .from('stock')
          .select('quantity, locations!inner(name), products_design!inner(design_no)')
          .eq('shop_id', shopId)
          .lt('quantity', 3)
          .order('quantity', ascending: true);
      return List<Map<String, dynamic>>.from(res);

    case 'trending':
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toUtc().toIso8601String();
      final res = await client
          .from('sales_entries')
          .select('quantity, products_design!inner(design_no)')
          .eq('shop_id', shopId)
          .gte('created_at', thirtyDaysAgo);
      
      final stats = <String, int>{};
      for (final item in res) {
        final designNo = (item['products_design'] as Map)['design_no'] as String;
        final qty = item['quantity'] as int;
        stats[designNo] = (stats[designNo] ?? 0) + qty;
      }
      
      final list = stats.entries.map((e) => {'design_no': e.key, 'quantity': e.value}).toList();
      list.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
      return list;
    
    default:
      return [];
  }
});
