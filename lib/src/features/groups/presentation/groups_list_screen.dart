import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_picker/currency_picker.dart';
import 'group_detail_screen.dart';
import '../domain/group_model.dart';
import '../data/groups_repository.dart';
import '../../auth/data/auth_repository.dart';



class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsListStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SettleUp Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Join Group via Token',
            onPressed: () => _showJoinGroupDialog(context, ref),
          ),
        ],
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_outlined, size: 80, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 24),
                  Text(
                    'No groups yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Create a group to start tracking expenses'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GroupDetailScreen(group: group),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            group.currency,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Created ${_formatDate(group.createdAt)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        error: (err, st) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context, ref),
        label: const Text('New Group'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
  }

  void _showJoinGroupDialog(BuildContext context, WidgetRef ref) {
    final tokenController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Join Group'),
          content: TextField(
            controller: tokenController,
            decoration: const InputDecoration(labelText: 'Invite Token', hintText: 'Paste token here'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: isLoading ? null : () async {
                if (tokenController.text.isNotEmpty) {
                    setState(() => isLoading = true);
                    final user = ref.read(authControllerProvider).value;
                    if (user == null) return;
                    
                    try {
                      await ref.read(groupsRepositoryProvider).claimInvite(tokenController.text.trim(), user.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined group successfully!')));
                      }
                    } catch (e) {
                      setState(() => isLoading = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    
    // Get user's default currency
    final user = ref.read(authControllerProvider).value;
    final defaultCurrency = user?.defaultCurrency ?? 'USD';
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          bool isLoading = false;
          String selectedCurrency = defaultCurrency;
          Currency? currency = CurrencyService().findByCode(selectedCurrency);

          return AlertDialog(
            title: const Text('New Group', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController, 
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. Trip to Paris',
                    prefixIcon: Icon(Icons.group),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: isLoading ? null : () {
                    showCurrencyPicker(
                      context: dialogContext,
                      showFlag: true,
                      showCurrencyName: true,
                      showCurrencyCode: true,
                      onSelect: (Currency curr) {
                        setState(() {
                          selectedCurrency = curr.code;
                          currency = curr;
                        });
                      },
                      favorite: ['USD', 'EUR', 'GBP', 'INR', 'PKR'],
                    );
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      prefixIcon: Icon(Icons.attach_money),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      currency != null 
                        ? '${currency!.flag} ${currency!.code} - ${currency!.name}'
                        : selectedCurrency,
                      style: TextStyle(
                        color: isLoading ? Colors.grey : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogContext), 
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isLoading ? null : () async {
                  if (nameController.text.isNotEmpty) {
                    final user = ref.read(authControllerProvider).value;
                    if (user == null) return;
                    
                    setState(() => isLoading = true);
                    try {
                      await ref.read(groupsRepositoryProvider).createGroup(
                        nameController.text,
                        selectedCurrency,
                        user.id,  // Pass creator user ID
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      setState(() => isLoading = false);
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Error creating group: $e')),
                        );
                      }
                    }
                  }
                },
                child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}
