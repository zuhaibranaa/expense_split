import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_picker/currency_picker.dart';
import '../domain/group_model.dart';
import '../data/groups_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../people/data/members_repository.dart';
import '../../people/domain/member_model.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final Group group;

  const GroupSettingsScreen({super.key, required this.group});

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _isLoading = false;

  Future<Member?> _getCurrentUserMember() async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return null;

    final members = await ref.read(
      membersFutureProvider(widget.group.id).future,
    );
    return members.firstWhere(
      (m) => m.userId == user.id,
      orElse: () => Member(
        id: -1,
        groupId: widget.group.id,
        name: '',
        userId: null,
        isAdmin: 0,
      ),
    );
  }

  Future<bool> _isCurrentUserAdmin() async {
    final member = await _getCurrentUserMember();
    return member?.isAdmin == 1;
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersFutureProvider(widget.group.id));

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Group Info Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Group Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.group),
                            title: const Text('Group Name'),
                            subtitle: Text(widget.group.name),
                          ),
                          ListTile(
                            leading: const Icon(Icons.attach_money),
                            title: const Text('Currency'),
                            subtitle: Text(widget.group.currency),
                            trailing: FutureBuilder<bool>(
                              future: _isCurrentUserAdmin(),
                              builder: (context, snapshot) {
                                if (snapshot.data == true) {
                                  return IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        _showChangeCurrencyDialog(),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Members Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Members',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          membersAsync.when(
                            data: (members) => Column(
                              children: members
                                  .map((member) => _buildMemberTile(member))
                                  .toList(),
                            ),
                            error: (e, s) => Text('Error: $e'),
                            loading: () => const CircularProgressIndicator(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Danger Zone
                  FutureBuilder<bool>(
                    future: _isCurrentUserAdmin(),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Danger Zone',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(color: Colors.red),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () => _showDeleteGroupDialog(),
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Delete Group',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMemberTile(Member member) {
    return FutureBuilder<Member?>(
      future: _getCurrentUserMember(),
      builder: (context, snapshot) {
        final currentMember = snapshot.data;
        final isCurrentUser = currentMember?.userId == member.userId;
        final isAdmin = currentMember?.isAdmin == 1;

        return ListTile(
          leading: CircleAvatar(
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            ),
          ),
          title: Row(
            children: [
              Text(member.name),
              if (member.isAdmin == 1) ...[
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: member.iban != null && member.iban!.isNotEmpty
              ? GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: member.iban!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('IBAN copied: ${member.iban}')),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "IBAN: ${member.iban}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy, size: 12, color: Colors.blue),
                      ],
                    ),
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdmin || isCurrentUser)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditMemberDialog(member),
                ),
              if (isAdmin && !isCurrentUser)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () => _showRemoveMemberDialog(member),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showChangeCurrencyDialog() {
    showCurrencyPicker(
      context: context,
      showFlag: true,
      showCurrencyName: true,
      showCurrencyCode: true,
      onSelect: (Currency currency) async {
        setState(() => _isLoading = true);
        try {
          final user = ref.read(authControllerProvider).value;
          if (user == null) return;

          await ref
              .read(groupsListProvider.notifier)
              .updateGroup(widget.group.id, currency: currency.code);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Currency changed to ${currency.code}')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      favorite: ['USD', 'EUR', 'GBP', 'INR', 'PKR'],
    );
  }

  void _showEditMemberDialog(Member member) {
    final nameController = TextEditingController(text: member.name);

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Member Name'),
              content: TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: !isLoading,
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty) return;

                          setState(() => isLoading = true);
                          try {
                            final user = ref.read(authControllerProvider).value;
                            if (user == null) return;

                            await ref
                                .read(
                                  membersFutureProvider(
                                    widget.group.id,
                                  ).notifier,
                                )
                                .updateMember(
                                  member.id,
                                  user.id,
                                  name: nameController.text.trim(),
                                );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRemoveMemberDialog(Member member) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${member.name} from this group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              try {
                final user = ref.read(authControllerProvider).value;
                if (user == null) return;

                await ref
                    .read(membersFutureProvider(widget.group.id).notifier)
                    .removeMember(member.id, user.id);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${member.name} removed from group'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone and will delete all expenses and members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              try {
                final user = ref.read(authControllerProvider).value;
                if (user == null) return;

                await ref
                    .read(groupsRepositoryProvider)
                    .deleteGroup(widget.group.id, user.id);

                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
