import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expenses_repository.dart';
import '../../people/data/members_repository.dart';
import '../../people/domain/member_model.dart';

enum SplitMethod { equal, exact }

class AddExpenseScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupCurrency;  // Add group currency

  const AddExpenseScreen({super.key, required this.groupId, required this.groupCurrency});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  int? _selectedPayerId;
  String _selectedCategory = 'General';
  
  SplitMethod _splitMethod = SplitMethod.equal;
  final Map<int, TextEditingController> _splitControllers = {};

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (var c in _splitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersStreamProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Expense'),
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('Add people to the group first!'));
          }
          
          // Default payer initialization
          if (_selectedPayerId == null && members.isNotEmpty) {
             _selectedPayerId = members.first.id;
             // Initialize controllers for exact split
             for (var m in members) {
               _splitControllers[m.id] = TextEditingController(text: '0.00');
             }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Description
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                
                // Amount
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Total Amount (${widget.groupCurrency})',
                    prefixIcon: const Icon(Icons.attach_money),
                    helperText: 'Currency: ${widget.groupCurrency}',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => setState(() {}), 
                ),
                const SizedBox(height: 16),
                
                // Payer
                DropdownButtonFormField<int>(
                  value: _selectedPayerId,
                  decoration: const InputDecoration(
                    labelText: 'Paid By',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: members.map((m) {
                    return DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedPayerId = val);
                  },
                ),
                const SizedBox(height: 16),

                // Category
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: ['General', 'Food & Drinks', 'Housing', 'Transport', 'Utilities', 'Entertainment'].map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCategory = val ?? 'General');
                  },
                ),
                const SizedBox(height: 24),
                
                // Split Method Toggle
                SegmentedButton<SplitMethod>(
                  segments: const [
                    ButtonSegment(value: SplitMethod.equal, label: Text('Equal')),
                    ButtonSegment(value: SplitMethod.exact, label: Text('Exact Amount')),
                  ],
                  selected: {_splitMethod},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _splitMethod = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Split Details
                Text('Split Details', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_splitMethod == SplitMethod.equal) 
                  _buildEqualSplitView(members)
                else 
                  _buildExactSplitView(members),

                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _submit(members),
                  icon: const Icon(Icons.check),
                  label: const Text('Save Expense'),
                ),
              ],
            ),
          );
        },
        error: (err, st) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildEqualSplitView(List<Member> members) {
    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    final perPerson = members.isNotEmpty ? totalAmount / members.length : 0.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Split equally between ${members.length} people'),
            const SizedBox(height: 4),
            Text(
              '${widget.groupCurrency} ${perPerson.toStringAsFixed(2)} / person', 
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExactSplitView(List<Member> members) {
    return Column(
      children: members.map((member) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(member.name)),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _splitControllers[member.id],
                  decoration: InputDecoration(
                    prefixText: '${widget.groupCurrency} ',
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _submit(List<Member> members) async {
    final desc = _descriptionController.text.trim();
    final totalAmount = double.tryParse(_amountController.text);
    
    if (desc.isEmpty || totalAmount == null || totalAmount <= 0 || _selectedPayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in valid description and amount')),
      );
      return;
    }

    // Calculate Splits
    final Map<int, double> splits = {};
    if (_splitMethod == SplitMethod.equal) {
       final splitAmount = totalAmount / members.length;
       for (var m in members) {
         splits[m.id] = splitAmount;
       }
    } else {
      // Exact split logic
      double sumCheck = 0.0;
      for (var m in members) {
        final val = double.tryParse(_splitControllers[m.id]?.text ?? '0') ?? 0.0;
        splits[m.id] = val;
        sumCheck += val;
      }

      // Allow a small epsilon for floating point math, but warn if totally off
      if ((sumCheck - totalAmount).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Splits sum (${widget.groupCurrency} $sumCheck) must equal Total (${widget.groupCurrency} $totalAmount)')),
        );
        return;
      }
    }

    final navigator = Navigator.of(context);
    try {
      await ref.read(expensesRepositoryProvider).createExpense(
        groupId: widget.groupId,
        description: desc,
        amount: totalAmount,
        payerId: _selectedPayerId!,
        category: _selectedCategory,
        date: DateTime.now(),
        splits: splits,
      );
      if (navigator.mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
