import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_model.dart';

import 'package:intl/intl.dart';
import '../../people/domain/member_model.dart';
import '../../groups/data/groups_repository.dart';
import '../../../core/network/websocket_service.dart';
import '../../auth/data/auth_repository.dart';
import 'add_expense_screen.dart';

class ExpensesListScreen extends ConsumerWidget {
  final int groupId;
  final String groupCurrency; // Add group currency

  const ExpensesListScreen({
    super.key,
    required this.groupId,
    required this.groupCurrency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    // Listen for WebSocket events for this group
    ref.listen(webSocketEventsProvider, (previous, next) {
      next.whenData((event) {
        if (event['group_id'] == groupId) {
          // Refresh expenses
          ref.invalidate(expensesStreamProvider(groupId));

          // Show notification if it's a new expense (and not by me? backend doesn't tell 'me' distinctively yet, but user knows)
          if (event['type'] == 'expense_created') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(event['message'] ?? 'New expense added'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
            );
          }
        }
      });
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(
                groupId: groupId,
                groupCurrency: groupCurrency,
              ),
            ),
          );
        },
        label: const Text('Add Expense'),
        icon: const Icon(Icons.receipt_long),
      ),
      body: expensesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No expenses yet. Add one!'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              return await ref.refresh(expensesStreamProvider(groupId).future);
            },
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer,
                    child: const Icon(Icons.attach_money),
                  ),
                  title: Text(item.description),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paid by ${item.payer?.name ?? 'Unknown'}'),
                      // Show small avatars for splits
                      if (item.splits.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              "Split: ",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            ...item.splits
                                .map((split) {
                                  // Find member name/initials
                                  final matches = membersAsync.value?.where(
                                    (m) => m.id == split.memberId,
                                  );
                                  final member =
                                      (matches != null && matches.isNotEmpty)
                                      ? matches.first
                                      : null;
                                  if (member == null) return const SizedBox();

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 2.0),
                                    child: Tooltip(
                                      message: member.name,
                                      child: CircleAvatar(
                                        radius: 8,
                                        backgroundImage:
                                            member.avatarUrl != null
                                            ? NetworkImage(member.avatarUrl!)
                                            : null,
                                        backgroundColor: Colors.grey.shade300,
                                        child: member.avatarUrl == null
                                            ? Text(
                                                member.name[0],
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                })
                                .take(5), // Limit to 5
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: Text(
                    item.amount.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _showExpenseDetails(
                    context,
                    ref,
                    item,
                    membersAsync.value ?? [],
                  ),
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

  void _showExpenseDetails(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    List<Member> members,
  ) async {
    final user = ref.read(authControllerProvider).value;
    final isCreatorOrPayer = user != null && (user.id == expense.payerId);
    // Ideally check creator too, but for MVP payer is proxy. Or admin. Set admin later.
    final currentUserMember = members.firstWhere(
      (m) => m.userId == user?.id,
      orElse: () => Member(id: -1, groupId: -1, name: ''),
    );
    final isAdmin = currentUserMember.isAdmin == 1;
    final canEdit = isCreatorOrPayer || isAdmin;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(expense.description),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: $groupCurrency ${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Category: ${expense.category}'),
            Text('Date: ${DateFormat.yMMMd().format(expense.date)}'),
            const SizedBox(height: 16),
            const Text(
              'Paid by:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(expense.payer?.name ?? 'Unknown'),
            const SizedBox(height: 16),
            const Text(
              'Split between:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...expense.splits.map((s) {
              final m = members.firstWhere(
                (m) => m.id == s.memberId,
                orElse: () => Member(id: -1, groupId: -1, name: 'Unknown'),
              );
              return Text(
                '${m.name}: $groupCurrency ${s.amount.toStringAsFixed(2)}',
              );
            }),
          ],
        ),
        actions: [
          if (canEdit) ...[
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(
                      groupId: groupId,
                      groupCurrency: groupCurrency,
                      expense: expense,
                    ),
                  ),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Expense?'),
                    content: const Text(
                      'Are you sure you want to delete this expense?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  Navigator.pop(dialogContext);
                  try {
                    await ref
                        .read(expensesRepositoryProvider)
                        .deleteExpense(groupId, expense.id, user!.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expense deleted')),
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
              },
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
