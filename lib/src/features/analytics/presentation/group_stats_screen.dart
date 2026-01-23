import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/domain/expense_model.dart';
import '../../../shared/utils/currency_utils.dart';

class GroupStatsScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupCurrency;

  const GroupStatsScreen({
    super.key,
    required this.groupId,
    required this.groupCurrency,
  });

  @override
  ConsumerState<GroupStatsScreen> createState() => _GroupStatsScreenState();
}

class _GroupStatsScreenState extends ConsumerState<GroupStatsScreen> {
  int _periodIndex = 2; // 0: Month, 1: Quarter, 2: Year

  List<Expense> _filterExpenses(List<Expense> expenses) {
    if (_periodIndex == 2)
      return expenses; // Year (Show all for simplicity or current year)

    final now = DateTime.now();
    return expenses.where((e) {
      if (_periodIndex == 0) {
        // Current Month
        return e.date.year == now.year && e.date.month == now.month;
      } else if (_periodIndex == 1) {
        // Current Quarter
        final currentQuarter = ((now.month - 1) / 3).floor();
        final expenseQuarter = ((e.date.month - 1) / 3).floor();
        return e.date.year == now.year && currentQuarter == expenseQuarter;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesFutureProvider(widget.groupId));
    final currencySymbol = CurrencyUtils.getSymbol(widget.groupCurrency);

    return expensesAsync.when(
      data: (allExpenses) {
        final expenses = _filterExpenses(allExpenses);

        if (expenses.isEmpty) {
          return Column(
            children: [
              const SizedBox(height: 16),
              _buildPeriodSelector(),
              const Expanded(
                child: Center(
                  child: Text('No expenses found for this period.'),
                ),
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
            return await ref.refresh(
              expensesFutureProvider(widget.groupId).future,
            );
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildPeriodSelector()),
                const SizedBox(height: 24),

                // Summary Card (Matching StatsScreen)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF1E2235,
                    ), // Dark card bg from StatsScreen
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

                // Category List
                ...sortedCategories.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$currencySymbol ${e.value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${(e.value / totalSpending * 100).toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildPeriodSelector() {
    return ToggleButtons(
      isSelected: [_periodIndex == 0, _periodIndex == 1, _periodIndex == 2],
      onPressed: (index) => setState(() => _periodIndex = index),
      borderRadius: BorderRadius.circular(20),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Month'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Quarter'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Year'),
        ),
      ],
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
}
