import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/domain/expense_model.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../expenses/presentation/expenses_providers.dart';
import '../../cash_inflows/domain/cash_inflow_model.dart';
import 'package:intl/intl.dart';

class GroupStatsScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupCurrency;
  final bool isPersonal;

  const GroupStatsScreen({
    super.key,
    required this.groupId,
    required this.groupCurrency,
    this.isPersonal = false,
  });

  @override
  ConsumerState<GroupStatsScreen> createState() => _GroupStatsScreenState();
}

class _GroupStatsScreenState extends ConsumerState<GroupStatsScreen> {
  List<Expense> _filterExpenses(List<Expense> expenses, DateTimeRange? range) {
    if (range == null) return expenses;

    return expenses.where((e) {
      return e.date.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
          e.date.isBefore(range.end.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<CashInflow> _filterInflows(
    List<CashInflow> inflows,
    DateTimeRange? range,
  ) {
    if (range == null) return inflows;

    return inflows.where((i) {
      return i.date.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
          i.date.isBefore(range.end.add(const Duration(seconds: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesFutureProvider(widget.groupId));
    final currencySymbol = CurrencyUtils.getSymbol(widget.groupCurrency);
    final dateRange = ref.watch(expenseDateRangeFilterProvider(widget.groupId));

    // Watch inflows only for personal mode
    final inflowsAsync = widget.isPersonal
        ? ref.watch(inflowsListProvider(widget.groupId))
        : null;

    return expensesAsync.when(
      data: (allExpenses) {
        final expenses = _filterExpenses(allExpenses, dateRange);

        // Get inflows for personal mode
        List<CashInflow> inflows = [];
        if (widget.isPersonal && inflowsAsync != null) {
          inflows = inflowsAsync.valueOrNull ?? [];
          inflows = _filterInflows(inflows, dateRange);
        }

        if (widget.isPersonal) {
          return _buildPersonalStats(
            context,
            expenses,
            inflows,
            currencySymbol,
            dateRange,
          );
        } else {
          return _buildGroupStats(context, expenses, currencySymbol, dateRange);
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  // ==================== PERSONAL STATS ====================
  Widget _buildPersonalStats(
    BuildContext context,
    List<Expense> expenses,
    List<CashInflow> inflows,
    String currencySymbol,
    DateTimeRange? dateRange,
  ) {
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalIncome = inflows.fold(0.0, (sum, i) => sum + i.amount);
    final netBalance = totalIncome - totalExpenses;

    // Category Breakdown (Expenses)
    final expenseCategoryMap = <String, double>{};
    for (var e in expenses) {
      expenseCategoryMap[e.category] =
          (expenseCategoryMap[e.category] ?? 0) + e.amount;
    }
    final sortedExpenseCategories = expenseCategoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Category Breakdown (Income)
    final incomeCategoryMap = <String, double>{};
    for (var i in inflows) {
      incomeCategoryMap[i.category] =
          (incomeCategoryMap[i.category] ?? 0) + i.amount;
    }
    final sortedIncomeCategories = incomeCategoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bool hasData = expenses.isNotEmpty || inflows.isNotEmpty;

    if (!hasData) {
      return Column(
        children: [
          const SizedBox(height: 16),
          Center(child: _buildDatePill(dateRange)),
          const Expanded(
            child: Center(
              child: Text('No transactions found for this period.'),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // ignore: unused_result
        ref.refresh(expensesFutureProvider(widget.groupId));
        // ignore: unused_result
        ref.refresh(inflowsListProvider(widget.groupId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildDatePill(dateRange)),
            const SizedBox(height: 24),

            // Net Balance Card
            _buildNetBalanceCard(
              context,
              currencySymbol,
              netBalance,
              totalIncome,
              totalExpenses,
              expenses.length,
              inflows.length,
            ),

            // Income by Category
            if (sortedIncomeCategories.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'Income by Category',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              if (totalIncome > 0)
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
                          sections: sortedIncomeCategories.map((e) {
                            return PieChartSectionData(
                              color: _getIncomeCategoryColor(e.key),
                              value: e.value,
                              title: '',
                              radius: 20,
                            );
                          }).toList(),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$currencySymbol ${totalIncome.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green,
                              ),
                            ),
                            const Text(
                              'Income',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              ...sortedIncomeCategories.map(
                (e) => _buildCategoryRow(
                  e.key,
                  e.value,
                  totalIncome,
                  currencySymbol,
                  _getIncomeCategoryColor(e.key),
                ),
              ),
            ],

            // Expenses by Category
            if (sortedExpenseCategories.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'Spending by Category',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              if (totalExpenses > 0)
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
                          sections: sortedExpenseCategories.map((e) {
                            return PieChartSectionData(
                              color: _getCategoryColor(e.key),
                              value: e.value,
                              title: '',
                              radius: 20,
                            );
                          }).toList(),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$currencySymbol ${totalExpenses.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.redAccent,
                              ),
                            ),
                            const Text(
                              'Spent',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              ...sortedExpenseCategories.map(
                (e) => _buildCategoryRow(
                  e.key,
                  e.value,
                  totalExpenses,
                  currencySymbol,
                  _getCategoryColor(e.key),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNetBalanceCard(
    BuildContext context,
    String currencySymbol,
    double netBalance,
    double totalIncome,
    double totalExpenses,
    int expenseCount,
    int inflowCount,
  ) {
    final isPositive = netBalance >= 0;
    final balanceColor = isPositive ? Colors.green : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Net Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: balanceColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: balanceColor,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Balance',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  Text(
                    '${isPositive ? '+' : ''}$currencySymbol ${netBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: balanceColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // Income / Expense Row
          Row(
            children: [
              Expanded(
                child: _buildIncomeExpenseItem(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Income',
                  amount: '$currencySymbol ${totalIncome.toStringAsFixed(2)}',
                  count: '$inflowCount',
                  color: Colors.green,
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white10),
              Expanded(
                child: _buildIncomeExpenseItem(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Expenses',
                  amount: '$currencySymbol ${totalExpenses.toStringAsFixed(2)}',
                  count: '$expenseCount',
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseItem({
    required IconData icon,
    required String label,
    required String amount,
    required String count,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        Text(
          '$count transactions',
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
      ],
    );
  }

  // ==================== GROUP STATS (ORIGINAL) ====================
  Widget _buildGroupStats(
    BuildContext context,
    List<Expense> expenses,
    String currencySymbol,
    DateTimeRange? dateRange,
  ) {
    if (expenses.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 16),
          _buildDatePill(dateRange),
          const Expanded(
            child: Center(child: Text('No expenses found for this period.')),
          ),
        ],
      );
    }

    // 1. Basic Stats
    final totalSpending = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final avgExpense = totalSpending / expenses.length;

    // 2. Category Breakdown
    final categoryMap = <String, double>{};
    for (var e in expenses) {
      if (e.isSettlement) continue;
      categoryMap[e.category] = (categoryMap[e.category] ?? 0) + e.amount;
    }
    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 3. Top Spender
    final payerMap = <int, double>{};
    final payersInfo = <int, String>{};
    for (var e in expenses) {
      if (e.isSettlement) continue;
      payerMap[e.payerId] = (payerMap[e.payerId] ?? 0) + e.amount;
      if (e.payer != null) {
        payersInfo[e.payerId] = e.payer!.name;
      }
    }

    final topPayerId = payerMap.isNotEmpty
        ? payerMap.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : null;

    return RefreshIndicator(
      onRefresh: () async {
        return await ref.refresh(expensesFutureProvider(widget.groupId).future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildDatePill(dateRange)),
            const SizedBox(height: 24),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.trending_up,
                          color: Colors.cyan,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Spending',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          Text(
                            '$currencySymbol ${totalSpending.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem('Expenses', '${expenses.length}'),
                      _buildStatItem(
                        'Avg/Expense',
                        '$currencySymbol ${avgExpense.toStringAsFixed(0)}',
                      ),
                      if (topPayerId != null)
                        _buildStatItem(
                          'Top Spender',
                          payersInfo[topPayerId] ?? 'Unknown',
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(
              'Spending by Category',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Donut Chart
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: sortedCategories.map((e) {
                        return PieChartSectionData(
                          color: _getCategoryColor(e.key),
                          value: e.value,
                          title: '',
                          radius: 20,
                        );
                      }).toList(),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$currencySymbol ${totalSpending.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'Total',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Category List
            ...sortedCategories.map(
              (e) => _buildCategoryRow(
                e.key,
                e.value,
                totalSpending,
                currencySymbol,
                _getCategoryColor(e.key),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==================== SHARED WIDGETS ====================
  Widget _buildCategoryRow(
    String category,
    double value,
    double total,
    String currencySymbol,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currencySymbol ${value.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${(value / total * 100).toStringAsFixed(1)}%',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePill(DateTimeRange? range) {
    final text = range == null
        ? 'All Time'
        : DateFormat.yMMMM().format(range.start);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Housing':
        return Colors.teal;
      case 'Transport':
        return Colors.blue;
      case 'Utilities':
        return Colors.purple;
      case 'Food & Drinks':
        return Colors.orange;
      case 'Entertainment':
        return Colors.pink;
      default:
        return Colors.lightBlue;
    }
  }

  Color _getIncomeCategoryColor(String category) {
    switch (category) {
      case 'Salary':
        return Colors.green;
      case 'Freelance':
        return Colors.teal;
      case 'Investment':
        return Colors.indigo;
      case 'Gift':
        return Colors.amber;
      case 'Refund':
        return Colors.cyan;
      default:
        return Colors.lightGreen;
    }
  }
}
