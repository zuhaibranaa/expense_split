import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../groups/data/groups_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../data/members_repository.dart';
import '../../people/domain/member_model.dart';
import 'member_profile_screen.dart';

class MembersListView extends ConsumerWidget {
  final int groupId;

  const MembersListView({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersFutureProvider(groupId));
    final currentUser = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _showAddMemberDialog(context),
        tooltip: 'Add Person',
        child: const Icon(Icons.person_add),
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                return await ref.refresh(membersFutureProvider(groupId).future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(
                    child: Text('No people in this group yet.'),
                  ),
                ),
              ),
            );
          }

          // We need current user's member profile in this group to check for "SuperAdmin" (isAdmin=1)
          // Since we don't have it easily available, we can find it in the members list.
          // Fallback to basic user check if needed.
          final currentMember = members.firstWhere(
            (m) => m.userId == currentUser?.id,
            orElse: () => Member(
              id: -1,
              groupId: groupId,
              name: '',
              userId: null,
              isAdmin: 0,
            ),
          );

          final isSuperAdmin = currentMember.isAdmin == 1;

          return RefreshIndicator(
            onRefresh: () async {
              return await ref.refresh(membersFutureProvider(groupId).future);
            },
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];

                // Permission Logic:
                // Edit: Self OR (CurrentUser is SuperAdmin)
                // Delete: CurrentUser is SuperAdmin ONLY
                final isSelf = member.userId == currentUser?.id;
                final canEdit = isSelf || isSuperAdmin;
                final canDelete = isSuperAdmin && !isSelf;

                // If no actions available, just return the ListTile
                if (!canEdit && !canDelete) {
                  return _buildMemberTile(context, ref, member);
                }

                return Slidable(
                  key: ValueKey(member.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      if (canEdit)
                        SlidableAction(
                          onPressed: (context) =>
                              _showEditMemberDialog(context, ref, member),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          icon: Icons.edit,
                          label: 'Edit',
                        ),
                      if (canDelete)
                        SlidableAction(
                          onPressed: (context) =>
                              _showRemoveMemberDialog(context, ref, member),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                    ],
                  ),
                  child: _buildMemberTile(context, ref, member),
                );
              },
            ),
          );
        },
        error: (err, st) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, WidgetRef ref, Member member) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: member.avatarUrl != null
            ? NetworkImage(member.avatarUrl!)
            : null,
        child: member.avatarUrl == null
            ? Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?')
            : null,
      ),
      title: Text(member.name),
      subtitle: Row(
        children: [
          if (member.isAdmin == 1)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          if (member.userId != null)
            const Text(
              'Verified User',
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
        ],
      ),
      trailing: member.userId == null
          ? TextButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Invite'),
              onPressed: () => _generateInvite(context, ref, member),
            )
          : const Icon(Icons.chevron_right),
      onTap: () {
        if (member.userId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MemberProfileScreen(member: member),
            ),
          );
        }
      },
    );
  }

  Future<void> _generateInvite(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) async {
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    if (currentUser == null) return;

    try {
      final token = await ref
          .read(groupsRepositoryProvider)
          .generateInvite(groupId, member.id, currentUser.id);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invite Member'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Share this code with the person you want to invite:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade800),
                  ),
                  child: Center(
                    child: SelectableText(
                      token,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter this code in "Join Group"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: token));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Code copied!')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Code'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddMemberDialog(groupId: groupId),
    );
  }

  void _showEditMemberDialog(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) {
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
                            final user = ref
                                .read(authRepositoryProvider)
                                .currentUser;
                            if (user == null) return;

                            await ref
                                .read(membersFutureProvider(groupId).notifier)
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

  void _showRemoveMemberDialog(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
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
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);

                          try {
                            final user = ref
                                .read(authRepositoryProvider)
                                .currentUser;
                            if (user == null) return;

                            await ref
                                .read(membersFutureProvider(groupId).notifier)
                                .removeMember(member.id, user.id);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${member.name} removed from group',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (dialogContext.mounted) {
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
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AddMemberDialog extends ConsumerStatefulWidget {
  final int groupId;

  const AddMemberDialog({super.key, required this.groupId});

  @override
  ConsumerState<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<AddMemberDialog> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(membersFutureProvider(widget.groupId).notifier)
          .addMember(_nameController.text.trim());
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding member: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Person'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Alice',
        ),
        textCapitalization: TextCapitalization.words,
        autofocus: true,
        enabled: !_isLoading,
        onSubmitted: (_) => _addMember(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _addMember,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
