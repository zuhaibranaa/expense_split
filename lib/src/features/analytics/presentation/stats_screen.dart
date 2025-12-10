import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../groups/data/groups_repository.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/domain/expense_model.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch All Groups
    final groupsAsync = ref.watch(groupsListStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        centerTitle: true,
      ),
      body: groupsAsync.when(
        data: (groups) {
           if (groups.isEmpty) return const Center(child: Text("No groups found"));
           
           // 2. Fetch Expenses for All Groups (MVP Approach: Client-side Aggregation)
           // In a real app, use a dedicated endpoint /stats
           return _StatsContent(groupIds: groups.map((g) => g.id).toList());
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatsContent extends ConsumerStatefulWidget {
  final List<int> groupIds;
  const _StatsContent({required this.groupIds});

  @override
  ConsumerState<_StatsContent> createState() => _StatsContentState();
}

class _StatsContentState extends ConsumerState<_StatsContent> {
  int _periodIndex = 2; // 0: Month, 1: Quarter, 2: Year DEFAULTS to YEAR as per screenshot

  @override
  Widget build(BuildContext context) {
    final allExpensesAsync = ref.watch(allGroupsExpensesProvider(widget.groupIds));

    return allExpensesAsync.when(
      data: (expenses) {
        final totalSpending = expenses.fold(0.0, (sum, e) => sum + e.amount);
        final avgExpense = expenses.isEmpty ? 0.0 : totalSpending / expenses.length;
        
        // Calculate Category Data
        final categoryMap = <String, double>{};
        for (var e in expenses) {
          categoryMap[e.category] = (categoryMap[e.category] ?? 0) + e.amount;
        }

        final sortedCategories = categoryMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)); // Descending

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
               // Period Selector using Segmented Button styled manually or standard
               ToggleButtons(
                 isSelected: [_periodIndex == 0, _periodIndex == 1, _periodIndex == 2],
                 onPressed: (index) => setState(() => _periodIndex = index),
                 borderRadius: BorderRadius.circular(20),
                 children: const [
                   Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Month')),
                   Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Quarter')),
                   Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Year')),
                 ],
               ),
               const SizedBox(height: 24),

               // Total Spending Card
               Container(
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   color: const Color(0xFF1E2235), // Dark card bg
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
                             color: Colors.cyan.withOpacity(0.2),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: const Icon(Icons.trending_up, color: Colors.cyan),
                         ),
                         const SizedBox(width: 16),
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('Total Spending', style: TextStyle(color: Colors.grey[400])),
                             Text('\$${totalSpending.toStringAsFixed(2)}', 
                               style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
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
                          _buildStatItem('Expenses', expenses.length.toString()),
                          _buildStatItem('Groups', widget.groupIds.length.toString()),
                          _buildStatItem('Avg/Expense', '\$${avgExpense.toStringAsFixed(0)}'),
                        ],
                      )
                   ],
                 ),
               ),
               
               const SizedBox(height: 32),
               const Align(alignment: Alignment.centerLeft, child: Text('By Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
               const SizedBox(height: 16),

               // Donut Chart
               SizedBox(
                 height: 200,
                 child: Stack(
                   children: [
                     PieChart(
                       PieChartData(
                         sectionsSpace: 0,
                         centerSpaceRadius: 40,
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
                            Text('\$${totalSpending.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                         ],
                       ),
                     ),
                   ],
                 ),
               ),
               
               const SizedBox(height: 16),
               
               // Category List
               ...sortedCategories.map((e) => Padding(
                 padding: const EdgeInsets.symmetric(vertical: 8.0),
                 child: Row(
                   children: [
                     Container(width: 10, height: 10, decoration: BoxDecoration(color: _getCategoryColor(e.key), shape: BoxShape.circle)),
                     const SizedBox(width: 8),
                     Expanded(child: Text(e.key)),
                     Text('\$${e.value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                     const SizedBox(width: 16),
                     Text('${(e.value / totalSpending * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.grey)),
                   ],
                 ),
               )).toList(),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Housing': return Colors.teal;
      case 'Transport': return Colors.blue;
      case 'Utilities': return Colors.purple;
      case 'Food & Drinks': return Colors.orange;
      case 'Entertainment': return Colors.pink;
      default: return Colors.grey;
    }
  }
}

// Stats Provider to aggregate all groups
final allGroupsExpensesProvider = FutureProvider.family<List<Expense>, List<int>>((ref, groupIds) async {
  final repo = ref.watch(expensesRepositoryProvider);
  final allExpenses = <Expense>[];
  
  // Parallel fetch could be better but sticking to simple loop for now
  for (var id in groupIds) {
    final expenses = await repo.getExpensesList(id); // Need to expose getExpensesListFuture
    allExpenses.addAll(expenses);
  }
  return allExpenses;
});
