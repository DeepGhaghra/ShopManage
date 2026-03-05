import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/sales_providers.dart';
import '../../services/party_providers.dart';
import '../../services/product_providers.dart';
import '../../services/core_providers.dart';
import '../../models/party.dart';
import '../../models/product_head.dart';
import '../../models/pricelist.dart';
import '../../theme/app_theme.dart';
import '../common/app_drawer.dart';
import '../../utils/error_translator.dart';

class PricelistScreen extends ConsumerStatefulWidget {
  const PricelistScreen({super.key});

  @override
  ConsumerState<PricelistScreen> createState() => _PricelistScreenState();
}

class _PricelistScreenState extends ConsumerState<PricelistScreen> {
  Party? _selectedParty;
  Map<int, int> _partyPrices = {};
  bool _isLoadingPrices = false;
  bool _isSaving = false;
  String _productSearchQuery = '';

  // Controllers for prices to allow editing
  final Map<int, TextEditingController> _priceControllers = {};

  Future<void> _fetchPartyPricelist(int partyId) async {
    final activeShop = ref.read(activeShopProvider);
    if (activeShop == null) return;

    setState(() => _isLoadingPrices = true);
    try {
      final records = await ref.read(salesRepositoryProvider).getPricelistForParty(activeShop.id, partyId);
      final newPrices = <int, int>{};
      for (var rec in records) {
        newPrices[rec['product_id'] as int] = rec['price'] as int;
      }
      
      setState(() {
        _partyPrices = newPrices;
        // Update controllers with new prices
        _partyPrices.forEach((prodId, price) {
          if (_priceControllers.containsKey(prodId)) {
            _priceControllers[prodId]!.text = price.toString();
          }
        });
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${ErrorTranslator.translate(e)}')));
    } finally {
      if (mounted) setState(() => _isLoadingPrices = false);
    }
  }

  Future<void> _savePrice(int productId, String priceStr) async {
    final activeShop = ref.read(activeShopProvider);
    if (activeShop == null || _selectedParty == null) return;

    final price = int.tryParse(priceStr);
    if (price == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(salesRepositoryProvider).upsertPricelist(Pricelist(
        productId: productId,
        partyId: _selectedParty!.id,
        price: price,
        shopId: activeShop.id,
      ));
      
      setState(() {
        _partyPrices[productId] = price;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Price updated!'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${ErrorTranslator.translate(e)}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _priceControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partiesAsync = ref.watch(partiesProvider);
    final productsAsync = ref.watch(productHeadsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slightly darker for depth
      appBar: AppBar(
        centerTitle: true,
        title: Builder(builder: (context) {
          final isMobile = MediaQuery.of(context).size.width < 600;
          final activeShop = ref.watch(activeShopProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Party Pricelist', 
                style: TextStyle(
                  fontWeight: FontWeight.w800, 
                  color: AppColors.textPrimary,
                  fontSize: isMobile ? 16 : 20,
                )
              ),
              if (activeShop != null)
                Text(
                  activeShop.shopName,
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 11, 
                    fontWeight: FontWeight.bold, 
                    color: AppColors.accent, 
                    letterSpacing: 0.5
                  ),
                ),
            ],
          );
        }),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          if (_isLoadingPrices || _isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/pricelist'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              // ── Selection Header ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT PARTY', 
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade300, letterSpacing: 1.2)
                      ),
                      const SizedBox(height: 12),
                      partiesAsync.when(
                        data: (parties) => Autocomplete<Party>(
                          displayStringForOption: (p) => p.partyName,
                          optionsBuilder: (tv) {
                            if (tv.text.isEmpty) return parties;
                            return parties.where((p) => p.partyName.toLowerCase().contains(tv.text.toLowerCase()));
                          },
                          onSelected: (party) {
                            setState(() => _selectedParty = party);
                            _fetchPartyPricelist(party.id);
                          },
                          fieldViewBuilder: (context, controller, focusNode, onSub) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search Party Name...',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 13),
                                prefixIcon: const Icon(Icons.person, color: AppColors.primary, size: 20),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                suffixIcon: _selectedParty != null ? IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.grey, size: 18),
                                  onPressed: () {
                                    controller.clear();
                                    setState(() {
                                      _selectedParty = null;
                                      _partyPrices = {};
                                      // Controllers will be reset by the builder logic
                                    });
                                  },
                                ) : null,
                              ),
                            );
                          },
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text(ErrorTranslator.translate(e)),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Search & Filter Sticky Header ───────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverSearchDelegate(
                  child: Container(
                    color: const Color(0xFFF1F5F9), // Match bg to blend
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _productSearchQuery = v.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Filter Products...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Product List ─────────────────────────────────────────────
              productsAsync.when(
                data: (products) {
                  final filtered = products.where((p) {
                    final name = p.productName.toLowerCase();
                    final brand = (p.brandName ?? '').toLowerCase();
                    return name.contains(_productSearchQuery) || brand.contains(_productSearchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            Text('No active products found', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final prod = filtered[index];
                          final prodId = prod.id;
                          final prodName = prod.productName;
                          final brandName = prod.brandName ?? '';
                          final defaultRate = prod.productRate;
                          final partyRate = _partyPrices[prodId];

                          final displayValue = (partyRate ?? defaultRate).toString();

                          // Maintain controllers efficiently
                          final controller = _priceControllers.putIfAbsent(
                            prodId, 
                            () => TextEditingController(text: displayValue)
                          );

                          if (_selectedParty != null && controller.text != displayValue) {
                            // Only update if text is actually different to avoid builder loops
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && controller.text != displayValue) {
                                controller.text = displayValue;
                              }
                            });
                          } else if (_selectedParty == null && controller.text != defaultRate.toString()) {
                             WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) controller.text = defaultRate.toString();
                            });
                          }

                          return _ProductPriceCard(
                            brandName: brandName,
                            productName: prodName,
                            defaultRate: defaultRate,
                            controller: controller,
                            isModified: partyRate != null,
                            onSave: () => _selectedParty != null 
                              ? _savePrice(prodId, _priceControllers[prodId]!.text)
                              : ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a party first'))
                                ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverFillRemaining(child: Center(child: Text(ErrorTranslator.translate(e)))),
              ),
              
              // Bottom spacing
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverSearchDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverSearchDelegate({required this.child});

  @override
  double get minExtent => 90;
  @override
  double get maxExtent => 90;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverSearchDelegate oldDelegate) => true;
}

class _ProductPriceCard extends StatelessWidget {
  final String brandName;
  final String productName;
  final int defaultRate;
  final TextEditingController controller;
  final bool isModified;
  final VoidCallback onSave;

  const _ProductPriceCard({
    required this.brandName,
    required this.productName,
    required this.defaultRate,
    required this.controller,
    required this.isModified,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: isModified ? Border.all(color: AppColors.primary.withOpacity(0.15), width: 1.2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   if (brandName.isNotEmpty)
                    Text(
                      brandName.toUpperCase(), 
                      style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.3)
                    ),
                  Text(productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1), // Very light teal/mint
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4DB6AC), width: 1), // Distinct teal border
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, size: 10, color: Color(0xFF00796B)),
                        const SizedBox(width: 4),
                        Text(
                          'BASE RATE: ₹$defaultRate', 
                          style: const TextStyle(
                            color: Color(0xFF00796B), 
                            fontSize: 10, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 0.5
                          )
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 95,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: isModified ? AppColors.primary : Colors.blueGrey.shade900,
                ),
                onFieldSubmitted: (_) => onSave(),
                decoration: InputDecoration(
                  prefixText: '₹',
                  prefixStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: isModified ? AppColors.primary.withAlpha(5) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.check_circle_outline_rounded, color: isModified ? AppColors.primary : Colors.grey.shade300, size: 20),
                    onPressed: onSave,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
