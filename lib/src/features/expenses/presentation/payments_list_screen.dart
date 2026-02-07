import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/currency_utils.dart';
import '../data/expenses_repository.dart';
import '../../people/domain/member_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/data/groups_repository.dart';
import 'package:equisplit/src/shared/presentation/widgets/user_avatar.dart';

class PaymentsListScreen extends ConsumerWidget {
  final int groupId;
  final String groupCurrency;

  const PaymentsListScreen({
    super.key,
    required this.groupId,
    required this.groupCurrency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesFutureProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      body: expensesAsync.when(
        data: (allExpenses) {
          // Filter for settlements
          final payments = allExpenses
              .where(
                (e) => e.isSettlement || e.category.toLowerCase() == 'payment',
              )
              .toList();

          if (payments.isEmpty) {
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
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('No payments yet'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              return await ref.refresh(expensesFutureProvider(groupId).future);
            },
            child: ListView.builder(
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                final payerId = payment.payerId;
                // For settlements, usually there is one split receipt.
                // We'll try to find who received it.
                // The receiver is the one in splits (excluding payer if he happens to be there, but usually settlement pays to someone else)
                final split = payment.splits.isNotEmpty
                    ? payment.splits.first
                    : null;
                final receiverId = split?.memberId;

                final members = membersAsync.value ?? [];

                final payer = members.firstWhere(
                  (m) => m.id == payerId,
                  orElse: () =>
                      Member(id: -1, groupId: groupId, name: 'Unknown'),
                );

                final receiver = members.firstWhere(
                  (m) => m.id == receiverId,
                  orElse: () =>
                      Member(id: -1, groupId: groupId, name: 'Unknown'),
                );

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer,
                    child: Text(CurrencyUtils.getSymbol(groupCurrency)),
                  ),
                  title: RichText(
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(text: payer.name),
                        TextSpan(
                          text: ' paid ',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(text: receiver.name),
                      ],
                    ),
                  ),
                  subtitle: Text(
                    DateFormat.yMMMd().format(payment.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    '${CurrencyUtils.getSymbol(groupCurrency)}${payment.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  onTap: () => _showPaymentDetails(
                    context,
                    ref,
                    payment,
                    payer,
                    receiver,
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

  void _showPaymentDetails(
    BuildContext context,
    WidgetRef ref,
    dynamic payment, // Using dynamic or Expense type if imported
    Member payer,
    Member receiver,
  ) {
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
                    ).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    size: 32,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(payment.date),
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
                    '${CurrencyUtils.getSymbol(groupCurrency)} ${payment.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // People Involved
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      'FROM',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    UserAvatar(
                      name: payer.name,
                      avatarUrl: payer.avatarUrl,
                      radius: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payer.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Theme.of(context).colorScheme.outline,
                ),
                Column(
                  children: [
                    Text(
                      'TO',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    UserAvatar(
                      name: receiver.name,
                      avatarUrl: receiver.avatarUrl,
                      radius: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receiver.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Delete Action
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Payment?'),
                      content: const Text(
                        'Are you sure you want to delete this payment?',
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
                    final user = ref.read(authControllerProvider).value;
                    if (user != null) {
                      try {
                        await ref
                            .read(expensesFutureProvider(groupId).notifier)
                            .deleteExpense(payment.id, user.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment deleted')),
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
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                  foregroundColor: Theme.of(context).colorScheme.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
