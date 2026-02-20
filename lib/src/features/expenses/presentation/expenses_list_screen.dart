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

import 'expenses_providers.dart'; // For inflows provider
import '../../cash_inflows/domain/cash_inflow_model.dart';
import '../../cash_inflows/data/cash_inflow_repository.dart';

class ExpensesListScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupCurrency;
  final bool isPersonal;

  const ExpensesListScreen({
    super.key,
    required this.groupId,
    required this.groupCurrency,
    this.isPersonal = false,
  });

  @override
  ConsumerState<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends ConsumerState<ExpensesListScreen> {
  // Getters for easy access without changing entire file content logic
  int get groupId => widget.groupId;
  String get groupCurrency => widget.groupCurrency;
  bool get isPersonal => widget.isPersonal;

  bool _isFabExpanded = false;

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
    });
  }

  void _closeFab() {
    if (_isFabExpanded) {
      setState(() {
        _isFabExpanded = false;
      });
    }
  }

  void _navigateToAddExpense({bool isIncome = false}) {
    _closeFab();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => AddExpenseScreen(
              groupId: groupId,
              groupCurrency: groupCurrency,
              isPersonal: isPersonal,
              isIncome: isIncome,
            ),
          ),
        )
        .then((_) {
          // ignore: unused_result
          ref.refresh(expensesFutureProvider(groupId));
          if (isPersonal) {
            // ignore: unused_result
            ref.refresh(inflowsListProvider(groupId));
            ref.read(authControllerProvider.notifier).reloadUser();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesFutureProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    // For Personal: Watch inflows
    final inflowsAsync = isPersonal
        ? ref.watch(inflowsListProvider(groupId))
        : const AsyncValue<List<CashInflow>>.data([]);

    return Scaffold(
      appBar: null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isPersonal
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isFabExpanded) ...[
                  // Expense FAB
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          'Expense',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton.small(
                        heroTag: 'add_expense_mini_btn',
                        onPressed: () => _navigateToAddExpense(isIncome: false),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.arrow_upward),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Income FAB
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          'Income',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton.small(
                        heroTag: 'add_income_btn',
                        onPressed: () => _navigateToAddExpense(isIncome: true),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.arrow_downward),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Main Toggle FAB
                FloatingActionButton(
                  heroTag: 'main_fab',
                  onPressed: _toggleFab,
                  backgroundColor: _isFabExpanded ? Colors.grey : Colors.blue,
                  child: Icon(
                    _isFabExpanded ? Icons.close : Icons.add,
                    color: Colors.white,
                  ),
                ),
              ],
            )
          : FloatingActionButton.extended(
              heroTag: 'add_expense_btn',
              onPressed: () => _navigateToAddExpense(isIncome: false),
              label: const Text('Add Expense'),
              icon: const Icon(Icons.receipt_long),
            ),
      body: Stack(
        children: [
          // Main Content
          expensesAsync.when(
            data: (allExpenses) {
              // Flatten items
              final expenses = allExpenses.where((e) {
                return !e.isSettlement && e.category.toLowerCase() != 'payment';
              }).toList();

              final inflows = inflowsAsync.value ?? [];

              // Merge and Sort
              final List<dynamic> mergedItems = [...expenses, ...inflows];
              mergedItems.sort((a, b) {
                DateTime dateA;
                if (a is Expense) {
                  dateA = a.date;
                } else if (a is CashInflow) {
                  dateA = a.date;
                } else {
                  dateA = DateTime.now();
                }

                DateTime dateB;
                if (b is Expense) {
                  dateB = b.date;
                } else if (b is CashInflow) {
                  dateB = b.date;
                } else {
                  dateB = DateTime.now();
                }

                return dateB.compareTo(dateA); // Descending
              });

              if (mergedItems.isEmpty && !isPersonal) {
                return RefreshIndicator(
                  onRefresh: () async {
                    final _ = await ref.refresh(
                      expensesFutureProvider(groupId).future,
                    );
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: const Center(
                        child: Text('No expenses yet. Add one!'),
                      ),
                    ),
                  ),
                );
              }

              // Sticky Layout
              return Column(
                children: [
                  // 1. Fixed Header (Personal Only)
                  if (isPersonal) ...[
                    // Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade800, Colors.blue.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Current Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${ref.watch(authControllerProvider).value?.defaultCurrency ?? ""} ${ref.watch(authControllerProvider).value?.balance.toStringAsFixed(2) ?? "0.00"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 2. Scrollable List
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        // ignore: unused_result
                        await ref.refresh(
                          expensesFutureProvider(groupId).future,
                        );
                        if (isPersonal) {
                          // ignore: unused_result
                          ref.refresh(inflowsListProvider(groupId));
                          // Reload user for balance update
                          await ref
                              .read(authControllerProvider.notifier)
                              .reloadUser();
                        }
                      },
                      child: mergedItems.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: const Center(
                                  child: Text('No expenses yet. Add one!'),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: mergedItems.length,
                              padding: const EdgeInsets.only(bottom: 80),
                              itemBuilder: (context, index) {
                                // Note: Header is now sticky, so index maps directly to items

                                if (mergedItems.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Center(
                                      child: Text("No transactions found."),
                                    ),
                                  );
                                }

                                final item = mergedItems[index];

                                // 1. GROUP EXPENSE ITEM (Restored from HEAD)
                                if (!isPersonal && item is Expense) {
                                  final expense = item;

                                  // Calculate Amount Color (Restored Logic)
                                  final user = ref
                                      .watch(authControllerProvider)
                                      .value;
                                  final myMember = membersAsync.value
                                      ?.firstWhere(
                                        (m) => m.userId == user?.id,
                                        orElse: () => Member(
                                          id: -1,
                                          groupId: groupId,
                                          name: '',
                                        ),
                                      );
                                  final myMemberId = myMember?.id;

                                  final isPayer = expense.payerId == myMemberId;
                                  final isInvolved = expense.splits.any(
                                    (s) => s.memberId == myMemberId,
                                  );

                                  Color amountColor;
                                  if (isInvolved && !isPayer) {
                                    amountColor = Colors.red;
                                  } else if (isPayer) {
                                    amountColor = Colors.green;
                                  } else {
                                    amountColor = Theme.of(
                                      context,
                                    ).colorScheme.primary;
                                  }

                                  return ListTile(
                                    leading: _buildAvatar(
                                      expense.payer?.name,
                                      expense.payer?.avatarUrl,
                                      radius: 20,
                                    ),
                                    title: Text(
                                      expense.description,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            // Category Pill (Green)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.green
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                expense.category,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Splits
                                        if (expense.splits.isNotEmpty) ...[
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
                                              ...expense.splits
                                                  .map((split) {
                                                    // Find member (we need members list)
                                                    // Optimization: In HEAD, membersAsync was used.
                                                    // We have membersAsync.value here.
                                                    final member = membersAsync
                                                        .value
                                                        ?.firstWhere(
                                                          (m) =>
                                                              m.id ==
                                                              split.memberId,
                                                          orElse: () => Member(
                                                            id: -1,
                                                            groupId: -1,
                                                            name: 'User',
                                                          ),
                                                        );

                                                    if (member == null ||
                                                        member.id == -1) {
                                                      return const SizedBox();
                                                    }

                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 2.0,
                                                          ),
                                                      child: Tooltip(
                                                        message: member.name,
                                                        child: UserAvatar(
                                                          radius: 8,
                                                          avatarUrl:
                                                              member.avatarUrl,
                                                          name: member.name,
                                                          heroTag:
                                                              'expense_${expense.id}_split_list_${member.id}',
                                                        ),
                                                      ),
                                                    );
                                                  })
                                                  .take(5),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          (expense.payments.length > 1)
                                              ? 'Paid by ${expense.payments.length}'
                                              : 'Paid by ${expense.payer?.name ?? 'Unknown'}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${CurrencyUtils.getSymbol(groupCurrency)} ${expense.amount.toStringAsFixed(2)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: amountColor,
                                              ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showGroupExpenseDetails(
                                      context,
                                      ref,
                                      expense,
                                      membersAsync.value ?? [],
                                    ),
                                  );
                                }

                                // 2. PERSONAL EXPENSE / INFLOW ITEM (Unified)
                                final isExpense = item is Expense;
                                final isInflow = item is CashInflow;

                                String description = '';
                                String category = '';
                                double amount = 0.0;
                                String currency = groupCurrency;

                                if (isExpense) {
                                  final Expense e = item;
                                  description = e.description;
                                  category = e.category;
                                  amount = e.amount;
                                } else if (isInflow) {
                                  final CashInflow i = item;
                                  description = i.description;
                                  category = i.category;
                                  amount = i.amount;
                                  currency = i.currencyCode;
                                }

                                // Styling for Personal
                                Color color;
                                IconData icon;
                                Color bgColor;

                                if (isInflow) {
                                  color = Colors.green;
                                  icon = Icons.arrow_downward;
                                  bgColor = Colors.green.withValues(alpha: 0.1);
                                } else {
                                  // Personal Expense
                                  color = Colors.red;
                                  icon = Icons.arrow_upward;
                                  bgColor = Colors.red.withValues(alpha: 0.1);
                                }

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: bgColor,
                                    child: Icon(icon, color: color),
                                  ),
                                  title: Text(
                                    description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      // Category Pill
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: color.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              category.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${CurrencyUtils.getSymbol(currency)} ${amount.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showPersonalTransactionDetails(
                                    context,
                                    ref,
                                    item,
                                    membersAsync.value ?? [],
                                    isPersonal,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
            error: (err, st) => Center(child: Text('Error: $err')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isFabExpanded,
              child: GestureDetector(
                onTap: _closeFab,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isFabExpanded ? 1.0 : 0.0,
                  child: Container(color: Colors.black54),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupExpenseDetails(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
    List<Member> members,
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

            // Icon and Description (Legacy Style)
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
                      // Category Pill (Blue/Legacy)
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
                            fontSize: 12,
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
                    '${CurrencyUtils.getSymbol(widget.groupCurrency)} ${expense.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // People Involved (Legacy)
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
                              orElse: () =>
                                  Member(id: -1, groupId: -1, name: 'Unknown'),
                            );
                            return Tooltip(
                              message:
                                  '${member.name}: ${CurrencyUtils.getSymbol(widget.groupCurrency)}${p.amount.toStringAsFixed(2)}',
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
                                  '${memberValue.name}: ${CurrencyUtils.getSymbol(widget.groupCurrency)}${split.amount.toStringAsFixed(2)}',
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

            const SizedBox(height: 40),

            // Actions (Delete/Edit)
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
                              .read(
                                expensesFutureProvider(widget.groupId).notifier,
                              )
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
                            groupId: widget.groupId,
                            groupCurrency: widget.groupCurrency,
                            expense: expense,
                            isPersonal: false,
                          ),
                        ),
                      ).then((_) {
                        // ignore: unused_result
                        ref.refresh(expensesFutureProvider(widget.groupId));
                        ref.read(authControllerProvider.notifier).reloadUser();
                      });
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

  void _showPersonalTransactionDetails(
    BuildContext context,
    WidgetRef ref,
    dynamic item, // Expense or CashInflow
    List<Member> members,
    bool isPersonal,
  ) {
    // Unpack item
    Expense? expense;
    CashInflow? inflow;

    if (item is Expense) {
      expense = item;
    } else if (item is CashInflow) {
      inflow = item;
    }

    bool isExpense = expense != null;
    String description = expense?.description ?? inflow?.description ?? '';
    String category = expense?.category ?? inflow?.category ?? '';
    DateTime date = expense?.date ?? inflow?.date ?? DateTime.now();
    double amount = expense?.amount ?? inflow?.amount ?? 0.0;
    String currency = isExpense
        ? widget.groupCurrency
        : inflow?.currencyCode ?? widget.groupCurrency;

    // Determine Color
    Color color = Colors.blue; // Default, will be overridden
    if (!isExpense) {
      color = Colors.green;
    } else if (isPersonal) {
      color = Colors.red;
    }

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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 32,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 8),
                      // Category Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(date),
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
                    '${CurrencyUtils.getSymbol(currency)} ${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Delete / Edit Buttons (Consistent Style)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      // Delete Logic (Personal/Inflow)
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            isExpense ? 'Delete Expense?' : 'Delete Income?',
                          ),
                          content: Text(
                            isExpense
                                ? 'Are you sure you want to delete this expense?'
                                : 'Are you sure you want to delete this income?',
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
                        Navigator.pop(context);
                        try {
                          if (isExpense) {
                            final user = ref.read(authControllerProvider).value;
                            await ref
                                .read(
                                  expensesFutureProvider(
                                    widget.groupId,
                                  ).notifier,
                                )
                                .deleteExpense(expense!.id, user!.id);
                          } else {
                            await ref
                                .read(cashInflowRepositoryProvider)
                                .deleteInflow(inflow!.id);
                          }

                          // Refresh Logic
                          if (context.mounted) {
                            ref
                                .read(authControllerProvider.notifier)
                                .reloadUser();
                            // ignore: unused_result
                            ref.refresh(expensesFutureProvider(widget.groupId));
                            if (isPersonal) {
                              // ignore: unused_result
                              ref.refresh(inflowsListProvider(widget.groupId));
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction deleted'),
                              ),
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
                            groupId: widget.groupId,
                            groupCurrency: widget.groupCurrency,
                            expense: expense,
                            inflow: inflow,
                            isPersonal: isPersonal,
                            isIncome: !isExpense,
                          ),
                        ),
                      ).then((_) {
                        // ignore: unused_result
                        ref.refresh(expensesFutureProvider(widget.groupId));
                        if (isPersonal) {
                          // ignore: unused_result
                          ref.refresh(inflowsListProvider(widget.groupId));
                        }
                        ref.read(authControllerProvider.notifier).reloadUser();
                      });
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(isExpense ? 'Edit Expense' : 'Edit Income'),
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
