import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_model.dart';
import 'add_expense_screen.dart';

class ExpensesListScreen extends ConsumerWidget {
  final int groupId;
  final String groupCurrency;  // Add group currency

  const ExpensesListScreen({super.key, required this.groupId, required this.groupCurrency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider(groupId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
               builder: (context) => AddExpenseScreen(groupId: groupId, groupCurrency: groupCurrency),
            ),
          );
        },
        label: const Text('Add Expense'),
        icon: const Icon(Icons.receipt_long),
      ),
      body: expensesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No expenses yet. Add one!'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                  child: const Icon(Icons.attach_money),
                ),
                title: Text(item.description),
                subtitle: Text('Paid by ${item.payer?.name ?? 'Unknown'}'),
                trailing: Text(
                  item.amount.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            },
          );
        },
        error: (err, st) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
