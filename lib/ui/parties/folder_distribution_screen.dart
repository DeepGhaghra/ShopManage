import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/core_providers.dart';
import '../../services/folder_distribution_providers.dart';
import '../../services/dashboard_providers.dart';
import '../../models/folder_distribution.dart';
import '../../theme/app_theme.dart';
import '../common/app_bar_actions.dart';
import '../common/app_drawer.dart';
import '../common/app_bar_title.dart';
import '../common/error_view.dart';
import 'distribute_folder_dialog.dart';
import 'transaction_history_dialog.dart';

class FolderDistributionScreen extends ConsumerStatefulWidget {
  const FolderDistributionScreen({super.key});

  @override
  ConsumerState<FolderDistributionScreen> createState() =>
      _FolderDistributionScreenState();
}

class _FolderDistributionScreenState
    extends ConsumerState<FolderDistributionScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FolderDistribution> _filterDistributions(
    List<FolderDistribution> dists,
  ) {
    if (_searchQuery.isEmpty) return dists;
    final query = _searchQuery.toLowerCase();
    return dists.where((d) {
      final partyName = (d.partyName ?? '').toLowerCase();
      final folderName = (d.folderName ?? '').toLowerCase();
      return partyName.contains(query) || folderName.contains(query);
    }).toList();
  }

  Map<int, List<FolderDistribution>> _groupByParty(
    List<FolderDistribution> dists,
  ) {
    final Map<int, List<FolderDistribution>> grouped = {};
    for (var dist in dists) {
      grouped.putIfAbsent(dist.partyId, () => []).add(dist);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final activeShop = ref.watch(activeShopProvider);
    final distributionsAsync = ref.watch(folderDistributionsProvider);

    if (activeShop == null) {
      return const Scaffold(
        body: Center(child: Text('Please select a shop first.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        leadingWidth: 96,
        leading: Builder(
          builder: (context) {
            return Row(
              children: [
                const BackButton(color: AppColors.textPrimary),
                IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ],
            );
          },
        ),
        centerTitle: true,
        title: CustomAppBarTitle(
          title: 'Folder Distribution',
          subtitle: activeShop.shopName,
        ),
        actions: const [AppBarActions()],
      ),
      drawer: const AppDrawer(currentRoute: '/folder-distribution'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              _buildSearchBox(),
              Expanded(
                child: distributionsAsync.when(
                  data: (distributions) {
                    final filtered = _filterDistributions(distributions);
                    final grouped = _groupByParty(filtered);
                    return _buildContent(context, grouped);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => ErrorView(
                    error: err,
                    onRetry: () => ref.invalidate(folderDistributionsProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDistributeDialog(),
        label: const Text('New Distribution'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search party or folder...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.scaffoldBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<int, List<FolderDistribution>> groupedDistributions,
  ) {
    if (groupedDistributions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_shared_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No folders distributed yet.'
                  : 'No results found for "$_searchQuery"',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final partyIds = groupedDistributions.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: partyIds.length,
      itemBuilder: (context, index) {
        final partyId = partyIds[index];
        final distributions = groupedDistributions[partyId]!;
        return _buildUltraCompactPartyCard(partyId, distributions);
      },
    );
  }

  Widget _buildUltraCompactPartyCard(
    int partyId,
    List<FolderDistribution> folders,
  ) {
    final partyName = folders.first.partyName ?? 'Unknown Party';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sophisticated Header with Soft Blue Tint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF), // Clean light blue tint
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Colors.blue.shade50)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.business_center_rounded,
                  size: 20,
                  color: Color(0xFF1E88E5), // Primary blue
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    partyName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF334155), // Slate 700
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildActionIconButton(
                  icon: Icons.history_rounded,
                  onTap: () => _showHistory(partyId),
                  color: Colors.blueGrey.shade600,
                  tooltip: 'History',
                ),
                const SizedBox(width: 8),
                _buildActionIconButton(
                  icon: Icons.add_rounded,
                  onTap: () => _openDistributeDialog(partyId: partyId),
                  color: const Color(0xFF1E88E5),
                  tooltip: 'Give New',
                ),
              ],
            ),
          ),
          // Readable Folder Grid
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: folders.map((dist) => _buildFolderPill(dist)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required String tooltip,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildFolderPill(FolderDistribution dist) {
    return _InteractiveFolderPill(
      dist: dist,
      onTap: () => _showFolderActions(dist),
    );
  }

  void _showFolderActions(FolderDistribution dist) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.folder_shared_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dist.partyName ?? 'Party',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Folder: ${dist.folderName}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildQuantityBadge(dist.quantity),
              ],
            ),
            const SizedBox(height: 8),
            _buildActionItem(
              icon: Icons.add_circle_outline_rounded,
              label: 'Give More (Increase Quantity)',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _openDistributeDialog(initialDist: dist);
              },
            ),
            _buildActionItem(
              icon: Icons.remove_circle_outline_rounded,
              label: 'Return 1 Folder',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _returnFolder(dist, 1);
              },
            ),
            if (dist.quantity >= 2)
              _buildActionItem(
                icon: Icons.remove_circle_rounded,
                label: 'Return 2 Folders (At Once)',
                color: Colors.red.shade700,
                onTap: () {
                  Navigator.pop(context);
                  _returnFolder(dist, 2);
                },
              ),
            _buildActionItem(
              icon: Icons.history_rounded,
              label: 'View History (Transactions)',
              color: Colors.blueGrey,
              onTap: () {
                Navigator.pop(context);
                _showHistory(
                  dist.partyId,
                  folderId: dist.folderId,
                  folderName: dist.folderName,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: disabled ? Colors.grey : color),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: disabled ? Colors.grey : AppColors.textPrimary,
          fontSize: 13,
        ),
      ),
      onTap: onTap,
      enabled: !disabled,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildQuantityBadge(int quantity) {
    final color = quantity >= 2 ? Colors.orange : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$quantity QTY',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );
  }

  void _openDistributeDialog({FolderDistribution? initialDist, int? partyId}) {
    showDialog(
      context: context,
      builder: (context) => DistributeFolderDialog(
        initialDistribution: initialDist,
        initialPartyId: partyId,
      ),
    );
  }

  void _showHistory(int partyId, {int? folderId, String? folderName}) {
    showDialog(
      context: context,
      builder: (context) => TransactionHistoryDialog(
        partyId: partyId,
        folderId: folderId,
        folderName: folderName,
      ),
    );
  }

  Future<void> _returnFolder(FolderDistribution dist, int qty) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Return'),
        content: Text(
          'Return $qty "${dist.folderName}" from "${dist.partyName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final activeShop = ref.read(activeShopProvider);
        await ref
            .read(folderDistRepositoryProvider)
            .returnFolder(
              shopId: activeShop!.id,
              partyId: dist.partyId,
              folderId: dist.folderId,
              currentQuantity: dist.quantity,
              requestedQuantity: qty,
            );
        ref.invalidate(folderDistributionsProvider);
        // Refresh both specific and general history for this party
        ref.invalidate(
          folderTransactionsProvider((
            partyId: dist.partyId,
            folderId: dist.folderId,
          )),
        );
        ref.invalidate(
          folderTransactionsProvider((partyId: dist.partyId, folderId: null)),
        );
        ref.invalidate(dashboardMetricsProvider);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Folder returned.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// A dedicated widget to handle the hover effects for folder pills
class _InteractiveFolderPill extends StatefulWidget {
  final FolderDistribution dist;
  final VoidCallback onTap;

  const _InteractiveFolderPill({required this.dist, required this.onTap});

  @override
  State<_InteractiveFolderPill> createState() => _InteractiveFolderPillState();
}

class _InteractiveFolderPillState extends State<_InteractiveFolderPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isWarning = widget.dist.quantity >= 2;
    final accentColor = isWarning ? Colors.deepOrange : const Color(0xFF0F4C81);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _isHovered
                ? accentColor.withValues(alpha: 0.05)
                : Colors.white,
            border: Border.all(
              color: _isHovered ? accentColor : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? accentColor.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: _isHovered ? 10 : 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: 'Outfit',
                  color: _isHovered ? accentColor : const Color(0xFF334155),
                ),
                child: Text(widget.dist.folderName ?? '?'),
              ),
              const SizedBox(width: 14),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${widget.dist.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
