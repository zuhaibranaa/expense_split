import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../groups/data/groups_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../data/members_repository.dart';
import '../../people/domain/member_model.dart';

class MembersListView extends ConsumerWidget {
  final int groupId;

  const MembersListView({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider(groupId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberDialog(context, ref),
        label: const Text('Add Person'),
        icon: const Icon(Icons.person_add),
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('No people in this group yet.'));
          }
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(member.name[0].toUpperCase())),
                  title: Text(member.name),
                  subtitle: member.userId != null ? const Text('Verified User', style: TextStyle(fontSize: 12, color: Colors.green)) : null,
                  trailing: member.userId == null
                      ? IconButton(
                          icon: const Icon(Icons.link),
                          tooltip: 'Invite Link',
                          onPressed: () => _generateInvite(context, ref, member),
                        )
                      : null,
                );
            },
          );
        },
        error: (err, st) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _generateInvite(BuildContext context, WidgetRef ref, Member member) async {
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    if (currentUser == null) return;

    try {
      final token = await ref.read(groupsRepositoryProvider).generateInvite(groupId, member.id, currentUser.id);
      
      // Construct Link (Using relative path for web, would need real domain for mobile)
      final link = '${Uri.base.origin}/invite?token=$token';

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invite Link'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Share this link with the person you want to invite:'),
                const SizedBox(height: 16),
                SelectableText(link, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Person'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Alice'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(membersRepositoryProvider).addMember(groupId, nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

