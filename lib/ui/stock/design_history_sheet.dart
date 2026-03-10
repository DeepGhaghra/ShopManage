import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/stock_history_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_translator.dart';
import 'package:intl/intl.dart';

class DesignHistorySheet extends ConsumerStatefulWidget {
  final int designId;
  final String designNo;

  const DesignHistorySheet({
    super.key,
    required this.designId,
    required this.designNo,
  });

  @override
  ConsumerState<DesignHistorySheet> createState() => _DesignHistorySheetState();
}

class _DesignHistorySheetState extends ConsumerState<DesignHistorySheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(designHistoryProvider(widget.designId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ──
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40, height: 4, 
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))
                ),
              ),
              
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.history_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.designNo, 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)
                          ),
                          Text(
                            'Stock History Timeline', 
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // ── Search Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search... (try inv: loc: or date:)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
              
              // ── List ──
              Expanded(
                child: historyAsync.when(
                  data: (allItems) {
                    final items = allItems.where((item) {
                      final query = _searchQuery.trim().toLowerCase();
                      if (query.isEmpty) return true;
                      
                      final dateStr = DateFormat('dd MMM yy').format(item.date).toLowerCase();
                      final idStr = (item.identifier ?? '').toLowerCase();
                      final locStr = item.locationName.toLowerCase();
                      final partyStr = item.partyName.toLowerCase();
                      final typeStr = item.type.name.toLowerCase();
                      
                      // Advanced filters
                      if (query.startsWith('inv:')) {
                        return idStr.contains(query.substring(4).trim());
                      } else if (query.startsWith('loc:')) {
                        return locStr.contains(query.substring(4).trim());
                      } else if (query.startsWith('date:')) {
                        return dateStr.contains(query.substring(5).trim());
                      }

                      // Default: search across everything
                      return partyStr.contains(query) ||
                             locStr.contains(query) ||
                             typeStr.contains(query) ||
                             idStr.contains(query) ||
                             dateStr.contains(query);
                    }).toList();

                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No history match found', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        
                        Color color; IconData icon; String badgeText; String sign;
                        
                        switch (item.type) {
                          case TransactionType.purchase:
                            color = Colors.green.shade600; icon = Icons.add_shopping_cart_rounded; badgeText = 'PURCHASE'; sign = '+';
                            break;
                          case TransactionType.sale:
                            color = Colors.blue.shade600; icon = Icons.local_shipping_outlined; badgeText = 'SALE'; sign = '-'; // Note: db quantity is already negative for sales but we handle sign explicitly if needed.
                            break;
                          case TransactionType.transferIn:
                            color = Colors.teal.shade600; icon = Icons.input_rounded; badgeText = 'TRANSFER IN'; sign = '+';
                            break;
                          case TransactionType.transferOut:
                            color = Colors.grey.shade600; icon = Icons.output_rounded; badgeText = 'TRANSFER OUT'; sign = '-';
                            break;
                          case TransactionType.manualAdd:
                            color = Colors.deepPurple.shade500; icon = Icons.add_box_outlined; badgeText = 'MANUAL ADD'; sign = '+';
                            break;
                          case TransactionType.adjustment:
                            color = Colors.orange.shade700; icon = Icons.build_circle_outlined; badgeText = 'ADJUSTMENT'; sign = '';
                            break;
                        }
                        
                        // Handle sign display logic since quantity could be negative already from db
                        final absQty = item.quantity.abs();
                        final isPositive = sign == '+';
                        final displayQty = '${isPositive ? "+" : "-"}$absQty';
                        
                        final bgColor = color.withOpacity(0.1);

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon Box
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.partyName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                            ),
                                          ),
                                          Text(
                                            displayQty,
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              badgeText,
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
                                              const SizedBox(width: 4),
                                              Text(
                                                item.locationName,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                          if (item.identifier != null) ...[
                                            Text('•', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.receipt_long_outlined, size: 12, color: Colors.grey.shade400),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item.identifier!,
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ],
                                          Text('•', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                                          Text(
                                            DateFormat('dd MMM yy • hh:mm a').format(item.date),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text(ErrorTranslator.translate(err))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
