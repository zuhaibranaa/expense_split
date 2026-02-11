import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../features/expenses/presentation/expenses_providers.dart';
import '../../../features/groups/data/groups_repository.dart';

import 'user_filter_list.dart';

class FilterModal extends ConsumerWidget {
  final int groupId;
  final bool showDateFilter;
  final bool showSimplifyDebts;

  const FilterModal({
    super.key,
    required this.groupId,
    this.showDateFilter = true,
    this.showSimplifyDebts = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(expenseDateRangeFilterProvider(groupId));
    final selectedUserId = ref.watch(expenseUserFilterProvider(groupId));
    final membersAsync = ref.watch(allMembersFutureProvider(groupId));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

          Text(
            'Filters',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Date Filter Section
          if (showDateFilter) ...[
            Text(
              'DATE RANGE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: dateRange,
                      );
                      if (picked != null) {
                        ref
                                .read(
                                  expenseDateRangeFilterProvider(
                                    groupId,
                                  ).notifier,
                                )
                                .state =
                            picked;
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      dateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat.MMMd().format(dateRange.start)} - ${DateFormat.MMMd().format(dateRange.end)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (dateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      ref
                              .read(
                                expenseDateRangeFilterProvider(
                                  groupId,
                                ).notifier,
                              )
                              .state =
                          null;
                    },
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear Date Filter',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (showSimplifyDebts) ...[
            Text(
              'SETTINGS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final minimize = ref.watch(minimizeDebtsProvider(groupId));
                return SwitchListTile(
                  title: const Text('Simplify Debts'),
                  subtitle: const Text('Minimize total number of transactions'),
                  value: minimize,
                  onChanged: (val) {
                    ref.read(minimizeDebtsProvider(groupId).notifier).state =
                        val;
                  },
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          // User Filter Section
          Text(
            'FILTER BY MEMBER',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          membersAsync.when(
            data: (members) => UserFilterList(
              members: members,
              selectedMemberId: selectedUserId,
              onSelected: (id) {
                ref.read(expenseUserFilterProvider(groupId).notifier).state =
                    id;
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => const Text('Failed to load members'),
          ),

          const SizedBox(height: 32),

          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Show Results'),
          ),
        ],
      ),
    );
  }
}
