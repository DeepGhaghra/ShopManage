import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/party_providers.dart';
import '../../services/core_providers.dart';
import '../../models/party.dart';
import '../../theme/app_theme.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Parties'),
            if (ref.watch(activeShopProvider) != null)
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    ref.watch(activeShopProvider)!.shopName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
            tooltip: 'Search Parties',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditPartyDialog(context, ref),
            tooltip: 'Add Party',
          ),
        ],
      ),
      body: partiesAsync.when(
        data: (parties) {
          final filteredParties = parties.where((party) {
            final query = _searchQuery.toLowerCase();
            final matchesName = party.partyName.toLowerCase().contains(query);
            final matchesMobile = party.mobile?.contains(query) ?? false;
            return matchesName || matchesMobile;
          }).toList();

          return Column(
            children: [
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Name or Mobile...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    autofocus: true,
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              Expanded(
                child: filteredParties.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No parties found. Add one!' : 'No matching parties found.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredParties.length,
                        itemBuilder: (context, index) {
                          final party = filteredParties[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(party.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: ((party.city?.isNotEmpty ?? false) || (party.mobile?.isNotEmpty ?? false))
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (party.city?.isNotEmpty ?? false)
                                Text('City: ${party.city}', style: const TextStyle(fontSize: 12)),
                              if (party.mobile?.isNotEmpty ?? false)
                                Text('Mobile: ${party.mobile}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary), 
                        onPressed: () => _showAddEditPartyDialog(context, ref, party: party),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
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
            title: Text(party == null ? 'Add Party' : 'Edit Party'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Party Name *',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cityController,
                      decoration: const InputDecoration(
                        labelText: 'City Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          if (!RegExp(r'^[0-9]{10}$').hasMatch(val.trim())) {
                            return 'Enter a valid mobile no';
                          }
                        }
                        return null; // Optional field
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
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
                                  content: const Text('⚠️ A party with this name already exists'),
                                  backgroundColor: Colors.orange.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                            return;
                          }

                          if (enteredMobile.isNotEmpty) {
                            final mobileExists = currentParties.any((p) => 
                                p.id != party?.id && p.mobile == enteredMobile);
                            if (mobileExists) {
                              setState(() => isSaving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('⚠️ A party with this mobile number already exists'),
                                    backgroundColor: Colors.orange.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }
                              return;
                            }
                          }

                          try {
                            final repo = ref.read(partyRepositoryProvider);
                            if (party == null) {
                              await repo.addParty(Party(
                                id: 0, // Ignored by Supabase
                                partyName: nameController.text.trim(),
                                city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
                                mobile: mobileController.text.trim().isEmpty ? null : mobileController.text.trim(),
                                timeAdded: DateTime.now(), // Ignored by Supabase
                                shopId: activeShop.id,
                              ));
                            } else {
                              await repo.updateParty(Party(
                                id: party.id,
                                partyName: nameController.text.trim(),
                                city: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
                                mobile: mobileController.text.trim().isEmpty ? null : mobileController.text.trim(),
                                timeAdded: party.timeAdded,
                                shopId: party.shopId, // Keep original shop ID
                              ));
                            }
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(party == null ? '✅ Party added successfully!' : '✅ Party updated successfully!'),
                                  backgroundColor: Colors.green.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                            // Refresh list to show new data
                            ref.invalidate(partiesProvider);
                          } catch (e) {
                            setState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Error: $e'),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
