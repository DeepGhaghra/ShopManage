import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/core_providers.dart';
import '../../services/party_providers.dart';
import '../../services/folder_distribution_providers.dart';
import '../../services/dashboard_providers.dart';
import '../../models/party.dart';
import '../../models/folder.dart';
import '../../models/folder_distribution.dart';
import '../../theme/app_theme.dart';

import '../common/searchable_selector.dart';

class DistributeFolderDialog extends ConsumerStatefulWidget {
  final FolderDistribution? initialDistribution;
  final int? initialPartyId;

  const DistributeFolderDialog({
    super.key,
    this.initialDistribution,
    this.initialPartyId,
  });

  @override
  ConsumerState<DistributeFolderDialog> createState() =>
      _DistributeFolderDialogState();
}

class _DistributeFolderDialogState
    extends ConsumerState<DistributeFolderDialog> {
  Party? _selectedParty;
  Folder? _selectedFolder;
  int _quantity = 1;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final partiesAsync = ref.watch(partiesProvider);
    final foldersAsync = ref.watch(activeFoldersProvider);
    final allDistributions = ref.watch(folderDistributionsProvider).value ?? [];

    return AlertDialog(
      title: const Text(
        'Give Folder to Party',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECT PARTY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              partiesAsync.when(
                data: (parties) {
                  final partyMap = parties
                      .map((p) => {'id': p.id, 'partyname': p.partyName})
                      .toList();
                  final currentPartyId =
                      widget.initialDistribution?.partyId ??
                      widget.initialPartyId ??
                      _selectedParty?.id;
                  final party = parties
                      .where((p) => p.id == currentPartyId)
                      .firstOrNull;
                  final isPartyFixed =
                      widget.initialDistribution != null ||
                      widget.initialPartyId != null;

                  return InkWell(
                    onTap: isPartyFixed
                        ? null
                        : () => SearchableSelector.show(
                            context: context,
                            title: 'Select Party',
                            items: partyMap,
                            labelKey: 'partyname',
                            icon: Icons.person_rounded,
                            iconColor: AppColors.primary,
                            onSelected: (id) => setState(
                              () => _selectedParty = parties.firstWhere(
                                (p) => p.id == id,
                              ),
                            ),
                          ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPartyFixed
                            ? Colors.grey.shade100
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: isPartyFixed
                                ? Colors.grey
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              party?.partyName ?? 'Select Party',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isPartyFixed
                                    ? Colors.grey
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!isPartyFixed)
                            const Icon(
                              Icons.search_rounded,
                              size: 16,
                              color: Colors.grey,
                            ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error loading parties'),
              ),
              const SizedBox(height: 20),
              const Text(
                'SELECT FOLDER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              foldersAsync.when(
                data: (folders) {
                  final folderMap = folders
                      .map((f) => {'id': f.id, 'folder_name': f.folderName})
                      .toList();
                  final currentFolderId =
                      widget.initialDistribution?.folderId ??
                      _selectedFolder?.id;
                  final folder = folders
                      .where((f) => f.id == currentFolderId)
                      .firstOrNull;

                  return InkWell(
                    onTap: widget.initialDistribution != null
                        ? null
                        : () => SearchableSelector.show(
                            context: context,
                            title: 'Select Folder',
                            items: folderMap,
                            labelKey: 'folder_name',
                            icon: Icons.folder_open_rounded,
                            iconColor: AppColors.cardStock,
                            onSelected: (id) => setState(
                              () => _selectedFolder = folders.firstWhere(
                                (f) => f.id == id,
                              ),
                            ),
                          ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.folder_open_rounded,
                            size: 18,
                            color: AppColors.cardStock,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              folder?.folderName ?? 'Select Folder',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (widget.initialDistribution == null)
                            const Icon(
                              Icons.search_rounded,
                              size: 16,
                              color: Colors.grey,
                            ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error loading folders'),
              ),
              const SizedBox(height: 20),
              const Text(
                'QUANTITY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _quantity,
                items: [1, 2]
                    .map(
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text('$i Folder${i > 1 ? 's' : ''}'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _quantity = val ?? 1),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.pin_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Note: Maximum 2 folders per transaction.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _submit(allDistributions),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Give Folder'),
        ),
      ],
    );
  }

  Future<void> _submit(List<FolderDistribution> allDists) async {
    final partyId =
        widget.initialDistribution?.partyId ??
        widget.initialPartyId ??
        _selectedParty?.id;
    final folderId =
        widget.initialDistribution?.folderId ?? _selectedFolder?.id;

    if (partyId == null || folderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both party and folder.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final activeShop = ref.read(activeShopProvider);

      // Find current quantity for THIS specific folder
      final specificDist = allDists
          .where((d) => d.partyId == partyId && d.folderId == folderId)
          .firstOrNull;
      final currentQtyForThisFolder = specificDist?.quantity ?? 0;

      await ref
          .read(folderDistRepositoryProvider)
          .giveFolder(
            shopId: activeShop!.id,
            partyId: partyId,
            folderId: folderId,
            currentQuantity: currentQtyForThisFolder,
            requestedQuantity: _quantity,
            partyName: widget.initialDistribution?.partyName ?? _selectedParty?.partyName,
            folderName: widget.initialDistribution?.folderName ?? _selectedFolder?.folderName,
          );

      ref.invalidate(folderDistributionsProvider);
      // Invalidate both the specific folder history AND the general party history
      ref.invalidate(
        folderTransactionsProvider((partyId: partyId, folderId: folderId)),
      );
      ref.invalidate(
        folderTransactionsProvider((partyId: partyId, folderId: null)),
      );
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
