import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/stock_history_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_translator.dart';
import 'package:intl/intl.dart';

class DesignHistorySheet extends ConsumerWidget {
  final int designId;
  final String designNo;

  const DesignHistorySheet({
    super.key,
    required this.designId,
    required this.designNo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(designHistoryProvider(designId));

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
                        color: AppColors.primary.withValues(alpha: 0.1),
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
                            designNo, 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)
                          ),
                          Text(
                            'Stock History', 
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
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
              
              // ── List ──
              Expanded(
                child: historyAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No history found', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isPurchase = item.type == TransactionType.purchase;
                        final color = isPurchase ? Colors.green : Colors.blue;
                        final icon = isPurchase ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded;
                        final bgColor = isPurchase ? Colors.green.shade50 : Colors.blue.shade50;
                        final sign = isPurchase ? '+' : '-';
                        final badgeText = isPurchase ? 'PURCHASE' : 'SALE';

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon Box
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(icon, color: color, size: 24),
                                ),
                                const SizedBox(width: 16),
                                
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
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                            ),
                                          ),
                                          Text(
                                            '$sign${item.quantity}',
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.1),
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
                                          Text(
                                            '•',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            DateFormat('dd MMM yyyy • hh:mm a').format(item.date),
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
