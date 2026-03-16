import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/log_service.dart';
import '../../services/party_providers.dart';
import '../../services/core_providers.dart';
import '../../models/party.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_translator.dart';
import '../common/error_view.dart';
import '../common/empty_state_view.dart';
import '../common/app_drawer.dart';
import '../admin/admin_scaffold.dart';
import '../../utils/date_utils.dart';

class PartiesScreen extends ConsumerStatefulWidget {
  const PartiesScreen({super.key});

  @override
  ConsumerState<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends ConsumerState<PartiesScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partiesAsync = ref.watch(partiesProvider);
    final activeShop = ref.watch(activeShopProvider);

    return AdminScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      title: 'Parties',
      selectedShopId: activeShop?.id,
      onShopChanged: (val) {
        if (val == null) {
          ref.read(activeShopProvider.notifier).setShop(null);
        } else {
          final shopsAsync = ref.read(associatedShopsProvider);
          shopsAsync.whenData((shops) {
            final shop = shops.firstWhere((s) => s.id == val);
            ref.read(activeShopProvider.notifier).setShop(shop);
          });
        }
      },
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white, size: 20),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
              }
            });
          },
        ),
      ],
      drawer: const AppDrawer(currentRoute: '/parties'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditPartyDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Party', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: partiesAsync.when(
            data: (parties) {
              final filteredParties = parties.where((party) {
                final query = _searchQuery.toLowerCase();
                return party.partyName.toLowerCase().contains(query) || 
                       (party.mobile?.contains(query) ?? false);
              }).toList();

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(partiesProvider),
                color: AppColors.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    if (_isSearching)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search by Name or Mobile...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ),
                    
                    if (filteredParties.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateView(
                          title: _searchQuery.isEmpty ? 'No Parties Yet' : 'No matches found',
                          message: _searchQuery.isEmpty ? 'Tap the + button below to add your first party.' : 'Try adjusting your search terms.',
                          icon: Icons.people_outline_rounded,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final party = filteredParties[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: RepaintBoundary(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: Text(
                                      party.partyName[0].toUpperCase(),
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    party.partyName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Builder(builder: (context) {
                                      final isMobile = MediaQuery.of(context).size.width < 600;
                                      
                                      final cityInfo = party.city != null ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Flexible(child: Text(party.city!, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                                        ],
                                      ) : const SizedBox.shrink();

                                      final mobileInfo = party.mobile != null ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Flexible(child: Text(party.mobile!, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                                        ],
                                      ) : const SizedBox.shrink();

                                      if (isMobile) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (party.city != null) cityInfo,
                                            if (party.mobile != null) ...[
                                              const SizedBox(height: 4),
                                              mobileInfo,
                                            ],
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          if (party.city != null) ...[
                                            Flexible(child: cityInfo),
                                            const SizedBox(width: 12),
                                          ],
                                          if (party.mobile != null) ...[
                                            Flexible(child: mobileInfo),
                                          ],
                                        ],
                                      );
                                    }),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 26),
                                    onPressed: () => _showAddEditPartyDialog(context, ref, party: party),
                                  ),
                                ),
                              ));
                            },
                            childCount: filteredParties.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => ErrorView(
              error: err,
              onRetry: () => ref.invalidate(partiesProvider),
            ),
          ),
        ),
      ),
    );
  }
}

void _showAddEditPartyDialog(BuildContext context, WidgetRef ref, {Party? party}) {
  final nameController = TextEditingController(text: party?.partyName ?? '');
  final cityController = TextEditingController(text: party?.city ?? '');
  final mobileController = TextEditingController(text: party?.mobile ?? '');
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (context) {
      bool isSaving = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ref.watch(activeShopProvider) != null)
                  Text(
                    'SHOP: ${ref.watch(activeShopProvider)!.shopName.toUpperCase()}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.5),
                  ),
                Text(
                  party == null ? 'New Party' : 'Edit Party',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Party Name *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: cityController,
                      decoration: InputDecoration(
                        labelText: 'City Name',
                        prefixIcon: const Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: mobileController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: const Icon(Icons.phone_android_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        counterText: '',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          if (!RegExp(r'^[0-9]{10}$').hasMatch(val.trim())) {
                            return 'Enter 10 digit number';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setState(() => isSaving = true);
                          final activeShop = ref.read(activeShopProvider);
                          if (activeShop == null) {
                            setState(() => isSaving = false);
                            return;
                          }

                          final currentParties = ref.read(partiesProvider).value ?? [];
                          final enteredName = nameController.text.trim().toLowerCase();
                          final enteredMobile = mobileController.text.trim();

                          final nameExists = currentParties.any((p) => 
                              p.id != party?.id && p.partyName.toLowerCase() == enteredName);
                          if (nameExists) {
                            setState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('Name already exists', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange.shade800,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                            return;
                          }

                          try {
                            final log = ref.read(logServiceProvider);
                            final repo = ref.read(partyRepositoryProvider);
                            if (party == null) {
                              await repo.addParty(Party(
                                id: 0,
                                partyName: nameController.text.trim(),
                                city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
                                mobile: mobileController.text.trim().isEmpty ? null : mobileController.text.trim(),
                                timeAdded: DateTime.now().toIST(),
                                shopId: activeShop.id,
                              ));
                              log.success('Parties', 'New party "${nameController.text.trim()}" added');
                            } else {
                              await repo.updateParty(Party(
                                id: party.id,
                                partyName: nameController.text.trim(),
                                city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
                                mobile: mobileController.text.trim().isEmpty ? null : mobileController.text.trim(),
                                timeAdded: party.timeAdded,
                                shopId: party.shopId,
                              ));
                              log.success('Parties', 'Party "${nameController.text.trim()}" details updated');
                            }
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(party == null ? 'Party added!' : 'Party updated!', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                            ref.invalidate(partiesProvider);
                          } catch (e) {
                            ref.read(logServiceProvider).error('Parties', 'Failed to ${party == null ? 'add' : 'update'} party', e);
                            setState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(ErrorTranslator.translate(e), style: const TextStyle(fontWeight: FontWeight.w600))),
                                    ],
                                  ),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Party', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}
