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
    final membersAsync = ref.watch(membersStreamProvider(groupId));

    return Scaffold(
      body: balancesAsync.when(
        data: (transfers) {
          if (transfers.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                final future1 = ref.refresh(
                  expensesStreamProvider(groupId).future,
                );
                final future2 = ref.refresh(
                  membersStreamProvider(groupId).future,
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
              String getName(int id) => members
                  .firstWhere(
                    (m) => m.id == id,
                    orElse: () =>
                        Member(id: -1, groupId: groupId, name: 'Unknown'),
                  )
                  .name;

              return RefreshIndicator(
                onRefresh: () async {
                  // Refresh both dependencies
                  final future1 = ref.refresh(
                    expensesStreamProvider(groupId).future,
                  );
                  final future2 = ref.refresh(
                    membersStreamProvider(groupId).future,
                  );
                  await Future.wait([future1, future2]);
                },
                child: ListView.builder(
                  itemCount: transfers.length,
                  itemBuilder: (context, index) {
                    final transfer = transfers[index];
                    // Helper to get Member object
                    Member getMember(int id) => members.firstWhere(
                      (m) => m.id == id,
                      orElse: () =>
                          Member(id: -1, groupId: groupId, name: 'Unknown'),
                    );

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
                                // Avatar or Icon
                                CircleAvatar(
                                  child: Text(
                                    getName(transfer.fromMemberId)[0],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: Colors.grey,
                                  ),
                                ),
                                CircleAvatar(
                                  child: Text(getName(transfer.toMemberId)[0]),
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
                                          text: getName(transfer.fromMemberId),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const TextSpan(text: ' owes '),
                                        TextSpan(
                                          text: getName(transfer.toMemberId),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        builder: (context) => SettleUpScreen(
                                          groupId: groupId,
                                          payer: getMember(
                                            transfer.fromMemberId,
                                          ),
                                          receiver: getMember(
                                            transfer.toMemberId,
                                          ),
                                          amount: transfer.amount,
                                          groupCurrency: groupCurrency,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.check),
                                  label: const Text('Settle Up'),
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

final balancesProvider = Provider.family
    .autoDispose<AsyncValue<List<BalanceTransfer>>, int>((ref, groupId) {
      final expensesAsync = ref.watch(expensesStreamProvider(groupId));
      final membersAsync = ref.watch(membersStreamProvider(groupId));

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
        BalanceCalculator.calculateBalances(expenses, members),
      );
    });
