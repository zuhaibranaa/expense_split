import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equisplit/src/features/groups/data/groups_repository.dart';
import 'package:equisplit/src/features/expenses/data/expenses_repository.dart';
import 'package:equisplit/src/features/people/data/members_repository.dart';
import 'package:equisplit/src/features/expenses/domain/balance_calculator.dart';
import 'package:equisplit/src/features/auth/data/auth_repository.dart';
import 'package:equisplit/src/features/expenses/presentation/settle_up_screen.dart';
import 'package:equisplit/src/features/people/domain/member_model.dart';

class GlobalSettlementItem {
  final int groupId;
  final String groupName;
  final String groupCurrency;
  final Member me;
  final Member other;
  final double amount; // Positive if I am owed, Negative if I owe

  GlobalSettlementItem({
    required this.groupId,
    required this.groupName,
    required this.groupCurrency,
    required this.me,
    required this.other,
    required this.amount,
  });
}

final globalSettlementsProvider =
    FutureProvider.autoDispose<List<GlobalSettlementItem>>((ref) async {
      final user = ref.watch(authControllerProvider).value;
      if (user == null) return [];

      final groups = await ref
          .watch(groupsRepositoryProvider)
          .getGroups(user.id);
      final items = <GlobalSettlementItem>[];

      // Parallel fetch for efficiency
      await Future.wait(
        groups.map((group) async {
          final membersRepo = ref.read(membersRepositoryProvider);
          final expensesRepo = ref.read(expensesRepositoryProvider);

          final members = await membersRepo.getMembers(group.id);
          // Find myself in this group
          final me = members.firstWhere(
            (m) => m.userId == user.id,
            orElse: () => Member(id: -1, groupId: group.id, name: ''),
          );

          if (me.id == -1) return; // Not a member of this group

          final expenses = await expensesRepo.getExpenses(group.id);
          final transfers = BalanceCalculator.calculateBalances(
            expenses,
            members,
          );

          for (var transfer in transfers) {
            if (transfer.fromMemberId == me.id) {
              // I owe someone
              final other = members.firstWhere(
                (m) => m.id == transfer.toMemberId,
              );
              items.add(
                GlobalSettlementItem(
                  groupId: group.id,
                  groupName: group.name,
                  groupCurrency: group.currency,
                  me: me,
                  other: other,
                  amount: -transfer.amount, // Negative for debt
                ),
              );
            } else if (transfer.toMemberId == me.id) {
              // Someone owes me
              final other = members.firstWhere(
                (m) => m.id == transfer.fromMemberId,
              );
              items.add(
                GlobalSettlementItem(
                  groupId: group.id,
                  groupName: group.name,
                  groupCurrency: group.currency,
                  me: me,
                  other: other,
                  amount: transfer.amount, // Positive for credit
                ),
              );
            }
          }
        }),
      );

      return items;
    });

class GlobalSettlementsScreen extends ConsumerWidget {
  const GlobalSettlementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsAsync = ref.watch(globalSettlementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Settlements')),
      body: settlementsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                return await ref.refresh(globalSettlementsProvider.future);
              },
              child: Stack(
                children: [
                  ListView(),
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.green,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'You are all settled up!',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              return await ref.refresh(globalSettlementsProvider.future);
            },
            child: ListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = items[index];
                final isOwesMe = item.amount > 0;
                final amount = item.amount.abs();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group Name Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
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
                                item.groupName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                            if (!isOwesMe) // Only show settle button if I owe
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => SettleUpScreen(
                                        groupId: item.groupId,
                                        payer: item.me,
                                        receiver: item.other,
                                        amount: amount,
                                        groupCurrency: item.groupCurrency,
                                      ),
                                    ),
                                  );
                                  // Refresh list
                                  return ref.refresh(
                                    globalSettlementsProvider.future,
                                  );
                                },
                                icon: const Icon(Icons.payment, size: 16),
                                label: const Text('Pay'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Debt Details
                        Row(
                          children: [
                            Icon(
                              isOwesMe ? Icons.arrow_back : Icons.arrow_forward,
                              color: isOwesMe ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOwesMe
                                        ? '${item.other.name} owes you'
                                        : 'You owe ${item.other.name}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    '${item.groupCurrency} ${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isOwesMe
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        error: (e, s) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
