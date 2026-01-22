import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/balance_calculator.dart';
import '../data/expenses_repository.dart';
import '../../people/data/members_repository.dart';
import '../../people/domain/member_model.dart';
import 'settle_up_screen.dart';

class BalancesScreen extends ConsumerWidget {
  final int groupId;
  final String groupCurrency; // Add group currency

  const BalancesScreen({
    super.key,
    required this.groupId,
    required this.groupCurrency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(balancesProvider(groupId));
    final membersAsync = ref.watch(membersFutureProvider(groupId));

    return Scaffold(
      body: balancesAsync.when(
        data: (transfers) {
          if (transfers.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                final future1 = ref.refresh(
                  expensesFutureProvider(groupId).future,
                );
                final future2 = ref.refresh(
                  membersFutureProvider(groupId).future,
                );
                await Future.wait([future1, future2]);
              },
              child: Stack(
                children: [
                  ListView(), // Always scrollable
                  const Center(child: Text('All settled up!')),
                ],
              ),
            );
          }

          return membersAsync.when(
            data: (members) {
              // Map ID to Name helper

              return RefreshIndicator(
                onRefresh: () async {
                  // Refresh both dependencies
                  final future1 = ref.refresh(
                    expensesFutureProvider(groupId).future,
                  );
                  final future2 = ref.refresh(
                    membersFutureProvider(groupId).future,
                  );
                  await Future.wait([future1, future2]);
                },
                child: Column(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final minimize = ref.watch(
                          minimizeDebtsProvider(groupId),
                        );
                        return SwitchListTile(
                          title: const Text('Simplify Debts'),
                          subtitle: const Text(
                            'Minimize total number of transactions',
                          ),
                          value: minimize,
                          onChanged: (val) {
                            ref
                                    .read(
                                      minimizeDebtsProvider(groupId).notifier,
                                    )
                                    .state =
                                val;
                          },
                        );
                      },
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: transfers.length,
                        itemBuilder: (context, index) {
                          final transfer = transfers[index];
                          // Helper to get Member object
                          Member getMember(int id) => members.firstWhere(
                            (m) => m.id == id,
                            orElse: () => Member(
                              id: -1,
                              groupId: groupId,
                              name: 'Unknown',
                            ),
                          );

                          final fromMember = getMember(transfer.fromMemberId);
                          final toMember = getMember(transfer.toMemberId);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ), // Adjusted padding
                              child: Column(
                                // Use Column for layout
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage:
                                            fromMember.avatarUrl != null
                                            ? NetworkImage(
                                                fromMember.avatarUrl!,
                                              )
                                            : null,
                                        child: fromMember.avatarUrl == null
                                            ? Text(
                                                fromMember.name.isNotEmpty
                                                    ? fromMember.name[0]
                                                          .toUpperCase()
                                                    : '?',
                                              )
                                            : null,
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      CircleAvatar(
                                        backgroundImage:
                                            toMember.avatarUrl != null
                                            ? NetworkImage(toMember.avatarUrl!)
                                            : null,
                                        child: toMember.avatarUrl == null
                                            ? Text(
                                                toMember.name.isNotEmpty
                                                    ? toMember.name[0]
                                                          .toUpperCase()
                                                    : '?',
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge,
                                            children: [
                                              TextSpan(
                                                text: fromMember.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const TextSpan(text: ' owes '),
                                              TextSpan(
                                                text: toMember.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "$groupCurrency ${transfer.amount.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.red,
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  SettleUpScreen(
                                                    groupId: groupId,
                                                    payer: getMember(
                                                      transfer.fromMemberId,
                                                    ),
                                                    receiver: getMember(
                                                      transfer.toMemberId,
                                                    ),
                                                    amount: transfer.amount,
                                                    groupCurrency:
                                                        groupCurrency,
                                                  ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.payment,
                                          size: 16,
                                        ),
                                        label: const Text('Pay'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
            error: (e, s) => Center(child: Text('Error loading members: $e')),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
        error: (err, st) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

final minimizeDebtsProvider = StateProvider.family<bool, int>(
  (ref, groupId) => true,
);

final balancesProvider = Provider.family
    .autoDispose<AsyncValue<List<BalanceTransfer>>, int>((ref, groupId) {
      final expensesAsync = ref.watch(expensesFutureProvider(groupId));
      final membersAsync = ref.watch(membersFutureProvider(groupId));
      final minimize = ref.watch(minimizeDebtsProvider(groupId));

      if (expensesAsync.isLoading || membersAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (expensesAsync.hasError) {
        return AsyncValue.error(
          expensesAsync.error!,
          expensesAsync.stackTrace!,
        );
      }

      if (membersAsync.hasError) {
        return AsyncValue.error(membersAsync.error!, membersAsync.stackTrace!);
      }

      // Both data available
      final expenses = expensesAsync.value ?? [];
      final members = membersAsync.value ?? [];

      return AsyncValue.data(
        BalanceCalculator.calculateBalances(
          expenses,
          members,
          minimize: minimize,
        ),
      );
    });
