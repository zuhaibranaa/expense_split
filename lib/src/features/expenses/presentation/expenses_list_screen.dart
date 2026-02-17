import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_model.dart';

import 'package:intl/intl.dart';
import '../../people/domain/member_model.dart';
import '../../groups/data/groups_repository.dart';
// import '../../../core/network/websocket_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/utils/currency_utils.dart';
import 'add_expense_screen.dart';
import 'package:equisplit/src/shared/presentation/widgets/user_avatar.dart';

class ExpensesListScreen extends ConsumerWidget {
  final int groupId;
  final String groupCurrency; // Add group currency
  final bool isPersonal;

  const ExpensesListScreen({
    super.key,
    required this.groupId,
    required this.groupCurrency,
    this.isPersonal = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesFutureProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    // Listen for WebSocket events for this group
    // ref.listen(webSocketEventsProvider, (previous, next) {
    //   next.whenData((event) {
    //     if (event['group_id'] == groupId) {
    //       // Refresh expenses
    //       ref.invalidate(expensesFutureProvider(groupId));

    //       // Show notification if it's a new expense (and not by me? backend doesn't tell 'me' distinctively yet, but user knows)
    //       if (event['type'] == 'expense_created') {
    //         ScaffoldMessenger.of(context).showSnackBar(
    //           SnackBar(
    //             content: Text(event['message'] ?? 'New expense added'),
    //             behavior: SnackBarBehavior.floating,
    //             backgroundColor: Theme.of(context).colorScheme.secondary,
    //           ),
    //         );
    //       }
    //     }
    //   });
    // });

    return Scaffold(
      appBar: null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(
                groupId: groupId,
                groupCurrency: groupCurrency,
                isPersonal: isPersonal,
              ),
            ),
          );
        },
        label: const Text('Add Expense'),
        icon: const Icon(Icons.receipt_long),
      ),
      body: expensesAsync.when(
        data: (allExpenses) {
          final items = allExpenses.where((e) {
            // Keep strictly view-logic filtering (hiding settlements in this view)
            // Date and Member filtering is now handled by the provider/backend
            return !e.isSettlement && e.category.toLowerCase() != 'payment';
          }).toList();
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                return await ref.refresh(
                  expensesFutureProvider(groupId).future,
                );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(child: Text('No expenses yet. Add one!')),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              return await ref.refresh(expensesFutureProvider(groupId).future);
            },
            child: Column(
              children: [
                // Filters Section
                // Filters container removed
                if (items.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        allExpenses.isEmpty
                            ? 'No expenses yet. Add one!'
                            : 'No expenses match filters.',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        // Find current user's member ID
                        final user = ref.watch(authControllerProvider).value;
                        final myMember = membersAsync.value?.firstWhere(
                          (m) => m.userId == user?.id,
                          orElse: () =>
                              Member(id: -1, groupId: groupId, name: ''),
                        );
                        final myMemberId = myMember?.id;

                        final isPayer = item.payerId == myMemberId;
                        final isInvolved = item.splits.any(
                          (s) => s.memberId == myMemberId,
                        );

                        Color amountColor;
                        if (isInvolved && !isPayer) {
                          amountColor = Colors.red;
                        } else if (isPayer) {
                          amountColor = Colors.green;
                        } else {
                          amountColor = Theme.of(context).colorScheme.primary;
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            child: Text(CurrencyUtils.getSymbol(groupCurrency)),
                          ),
                          title: Text(
                            item.description,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // Category Pill (Always Visible, Green)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      item.category,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Splits (Only for Non-Personal)
                              if (!isPersonal && item.splits.isNotEmpty) ...[
                                const SizedBox(height: 6),
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
                                          final matches = membersAsync.value
                                              ?.where(
                                                (m) => m.id == split.memberId,
                                              );
                                          final member =
                                              (matches != null &&
                                                  matches.isNotEmpty)
                                              ? matches.first
                                              : null;
                                          if (member == null) {
                                            return const SizedBox();
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 2.0,
                                            ),
                                            child: Tooltip(
                                              message: member.name,
                                              child: UserAvatar(
                                                radius: 8,
                                                avatarUrl: member.avatarUrl,
                                                name: member.name,
                                                heroTag:
                                                    'expense_${item.id}_split_list_${member.id}',
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
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isPersonal) ...[
                                Text(
                                  (item.payments.length > 1)
                                      ? 'Paid by ${item.payments.length}'
                                      : 'Paid by ${item.payer?.name ?? 'Unknown'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                item.amount.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: amountColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          onTap: () => _showExpenseDetails(
                            context,
                            ref,
                            item,
                            membersAsync.value ?? [],
                            isPersonal, // Pass isPersonal
                          ),
                        );
                      },
                    ),
                  ),
              ],
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
    bool isPersonal,
  ) {
    final user = ref.read(authControllerProvider).value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Icon and Description
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 8),
                      // Category Pill
                      // Category Pill (Blue/PaidBy Style in Detail Modal)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Text(
                          expense.category,
                          style: TextStyle(
                            fontSize: 12, // Slightly larger than list (10)
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(expense.date),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Amount Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Amount',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${CurrencyUtils.getSymbol(groupCurrency)} ${expense.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            if (!isPersonal) ...[
              const SizedBox(height: 32),

              // People Involved
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payer
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(context, 'PAID BY'),
                        const SizedBox(height: 12),
                        if (expense.payments.length > 1)
                          Wrap(
                            spacing: -8,
                            runSpacing: 8,
                            children: expense.payments.map((p) {
                              final member = members.firstWhere(
                                (m) => m.id == p.memberId,
                                orElse: () => Member(
                                  id: -1,
                                  groupId: -1,
                                  name: 'Unknown',
                                ),
                              );
                              return Tooltip(
                                message:
                                    '${member.name}: ${CurrencyUtils.getSymbol(groupCurrency)}${p.amount.toStringAsFixed(2)}',
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: _buildAvatar(
                                    member.name,
                                    member.avatarUrl,
                                    radius: 18,
                                    heroTag:
                                        'expense_${expense.id}_payment_detail_${member.id}',
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          _buildPersonCard(
                            context,
                            members
                                .firstWhere(
                                  (m) => m.id == expense.payerId,
                                  orElse: () => Member(
                                    id: -1,
                                    groupId: -1,
                                    name: expense.payer?.name ?? 'Unknown',
                                  ),
                                )
                                .name,
                            members
                                .firstWhere(
                                  (m) => m.id == expense.payerId,
                                  orElse: () => Member(
                                    id: -1,
                                    groupId: -1,
                                    name: expense.payer?.name ?? 'Unknown',
                                  ),
                                )
                                .avatarUrl,
                            isPayer: true,
                            heroTag:
                                'expense_${expense.id}_payer_detail_${expense.payerId}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Split With
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(context, 'SPLIT WITH'),
                        const SizedBox(height: 12),
                        // Stacked avatars or list
                        if (expense.splits.isEmpty)
                          Text(
                            'No splits',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          Wrap(
                            spacing: -8,
                            runSpacing: 8,
                            children: expense.splits.map((split) {
                              final memberValue = members.firstWhere(
                                (m) => m.id == split.memberId,
                                orElse: () =>
                                    Member(id: -1, groupId: -1, name: 'User'),
                              );
                              return Tooltip(
                                message:
                                    '${memberValue.name}: ${CurrencyUtils.getSymbol(groupCurrency)}${split.amount.toStringAsFixed(2)}',
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: _buildAvatar(
                                    memberValue.name,
                                    memberValue.avatarUrl,
                                    radius: 18,
                                    heroTag:
                                        'expense_${expense.id}_split_detail_${memberValue.id}',
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 40),

            // Actions
            // if (canEdit)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
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
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        Navigator.pop(context); // Close bottom sheet
                        try {
                          await ref
                              .read(expensesFutureProvider(groupId).notifier)
                              .deleteExpense(expense.id, user!.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Expense deleted')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      foregroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(
                            groupId: groupId,
                            groupCurrency: groupCurrency,
                            expense: expense,
                            isPersonal: isPersonal, // Pass isPersonal
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit Expense'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildPersonCard(
    BuildContext context,
    String name,
    String? avatarUrl, {
    bool isPayer = false,
    Object? heroTag,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(name, avatarUrl, radius: 20, heroTag: heroTag),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    String? name,
    String? avatarUrl, {
    double radius = 16,
    Object? heroTag,
  }) {
    return UserAvatar(
      radius: radius,
      avatarUrl: avatarUrl,
      name: name ?? '?',
      heroTag: heroTag,
    );
  }
}
