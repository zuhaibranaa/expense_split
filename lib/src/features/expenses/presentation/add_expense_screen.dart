import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expenses_repository.dart';
import '../../people/data/members_repository.dart';
import '../../people/domain/member_model.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/expense_model.dart';

enum SplitMethod { equal, exact }

class AddExpenseScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupCurrency; // Add group currency

  final Expense? expense;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.groupCurrency,
    this.expense,
  });

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
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit && widget.expense != null) {
      _descriptionController.text = widget.expense!.description;
      _amountController.text = widget.expense!.amount.toString();
      _selectedPayerId = widget.expense!.payerId;
      _selectedCategory = widget.expense!.category;

      // Handle splits
      // Start by initializing for all (will require members, so we do it in build/submit or logic below)
      // Actually, we can't initialize controllers here because we don't have members yet.
      // We'll rely on the FutureBuilder in build to initialize defaults, but we need to flag that we are editing.
      // To pre-fill custom splits, we'll need to match members.
    }
    _isInit = false;
  }

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
      appBar: AppBar(title: const Text('New Expense')),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('Add people to the group first!'));
          }

          // Default payer initialization or Edit Mode pre-fill
          if (_selectedPayerId == null) {
            if (widget.expense != null) {
              // Pre-fill from expense
              _selectedPayerId = widget.expense!.payerId;
              // Check if splits are equal or exact
              // Simple heuristic: if all splits are equal amount (approx) -> Equal, else Exact
              bool isEqual = true;
              if (widget.expense!.splits.isNotEmpty) {
                final firstAmount = widget.expense!.splits.first.amount;
                for (var s in widget.expense!.splits) {
                  if ((s.amount - firstAmount).abs() > 0.01) {
                    isEqual = false;
                    break;
                  }
                }
              }
              _splitMethod = isEqual ? SplitMethod.equal : SplitMethod.exact;

              // Init controllers
              for (var m in members) {
                final split = widget.expense!.splits.firstWhere(
                  (s) => s.memberId == m.id,
                  orElse: () => ExpenseSplit(id: -1, memberId: m.id, amount: 0),
                );
                final c = TextEditingController(
                  text: split.amount.toStringAsFixed(2),
                );
                if ((split.amount - (widget.expense!.amount / members.length))
                            .abs() >
                        0.01 &&
                    _splitMethod == SplitMethod.exact) {
                  // If loaded value differs from equal share, assume manual edit?
                  // Actually, safer to just add listener.
                  // But maybe we should mark as manually edited if we want to preserve it?
                  // The prompt implies behavior during *editing*, not initial load state.
                  // So we just add listener.
                }
                c.addListener(() => _onSplitAmountChanged(m.id, members));
                _splitControllers[m.id] = c;
              }
            } else if (members.isNotEmpty) {
              _selectedPayerId = members.first.id;
              // Initialize controllers for exact split
              for (var m in members) {
                final c = TextEditingController(text: '0.00');
                c.addListener(() => _onSplitAmountChanged(m.id, members));
                _splitControllers[m.id] = c;
              }
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                    return DropdownMenuItem(value: m.id, child: Text(m.name));
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
                  items:
                      [
                        'General',
                        'Food & Drinks',
                        'Housing',
                        'Transport',
                        'Utilities',
                        'Entertainment',
                      ].map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCategory = val ?? 'General');
                  },
                ),
                const SizedBox(height: 24),

                // Split Method Toggle
                SegmentedButton<SplitMethod>(
                  segments: const [
                    ButtonSegment(
                      value: SplitMethod.equal,
                      label: Text('Equal'),
                    ),
                    ButtonSegment(
                      value: SplitMethod.exact,
                      label: Text('Exact Amount'),
                    ),
                  ],
                  selected: {_splitMethod},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _splitMethod = newSelection.first;
                      if (_splitMethod == SplitMethod.exact) {
                        final totalAmount =
                            double.tryParse(_amountController.text) ?? 0.0;
                        if (totalAmount > 0 && members.isNotEmpty) {
                          final baseShare =
                              (totalAmount / members.length * 100).floor() /
                              100.0;
                          double remainder =
                              totalAmount - (baseShare * members.length);

                          _manuallyEditedMemberIds.clear();
                          _isProgrammaticUpdate = true;
                          for (var i = 0; i < members.length; i++) {
                            double share = baseShare;
                            if (i < (remainder * 100).round()) {
                              share += 0.01;
                            }
                            if (!_splitControllers.containsKey(members[i].id)) {
                              final c = TextEditingController(text: '0.00');
                              c.addListener(
                                () => _onSplitAmountChanged(
                                  members[i].id,
                                  members,
                                ),
                              );
                              _splitControllers[members[i].id] = c;
                            }
                            _splitControllers[members[i].id]?.text = share
                                .toStringAsFixed(2);
                          }
                          _isProgrammaticUpdate = false;
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Split Details
                Text(
                  'Split Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_splitMethod == SplitMethod.equal)
                  _buildEqualSplitView(members)
                else
                  _buildExactSplitView(members),

                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _submit(members),
                  icon: const Icon(Icons.check),
                  label: Text(
                    widget.expense == null ? 'Save Expense' : 'Update Expense',
                  ),
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

  final Set<int> _manuallyEditedMemberIds = {};
  bool _isProgrammaticUpdate = false;

  void _onSplitAmountChanged(int changedMemberId, List<Member> members) {
    if (_isProgrammaticUpdate) return;
    if (_splitMethod != SplitMethod.exact) return;

    setState(() {
      _manuallyEditedMemberIds.add(changedMemberId);
    });

    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;

    // Check if all members are manually edited
    final allEdited = members.every(
      (m) => _manuallyEditedMemberIds.contains(m.id),
    );

    if (allEdited) {
      // All manual: Update total from sum of splits
      double sum = 0.0;
      for (var m in members) {
        sum += double.tryParse(_splitControllers[m.id]?.text ?? '0') ?? 0.0;
      }
      if ((sum - totalAmount).abs() > 0.01) {
        _isProgrammaticUpdate = true;
        _amountController.text = sum.toStringAsFixed(2);
        _isProgrammaticUpdate = false;
      }
    } else {
      // Some unedited: Distribute remaining among them
      double manualSum = 0.0;
      final uneditedMembers = <Member>[];

      for (var m in members) {
        if (_manuallyEditedMemberIds.contains(m.id)) {
          manualSum +=
              double.tryParse(_splitControllers[m.id]?.text ?? '0') ?? 0.0;
        } else {
          uneditedMembers.add(m);
        }
      }

      double remaining = totalAmount - manualSum;
      if (remaining < 0)
        remaining =
            0; // Prevent negative shares if manual exceeds total (or let it go negative? usually 0)

      if (uneditedMembers.isNotEmpty) {
        final baseShare =
            (remaining / uneditedMembers.length * 100).floor() / 100.0;
        double leftover = remaining - (baseShare * uneditedMembers.length);

        _isProgrammaticUpdate = true;
        for (var i = 0; i < uneditedMembers.length; i++) {
          double share = baseShare;
          if (i < (leftover * 100).round()) {
            share += 0.01;
          }
          _splitControllers[uneditedMembers[i].id]?.text = share
              .toStringAsFixed(2);
        }
        _isProgrammaticUpdate = false;
      }
    }
  }

  Widget _buildExactSplitView(List<Member> members) {
    // Ensure controllers exist and have listeners
    for (var m in members) {
      if (!_splitControllers.containsKey(m.id)) {
        final c = TextEditingController(text: '0.00');
        c.addListener(() => _onSplitAmountChanged(m.id, members));
        _splitControllers[m.id] = c;
      }
    }

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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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

    if (desc.isEmpty ||
        totalAmount == null ||
        totalAmount <= 0 ||
        _selectedPayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in valid description and amount'),
        ),
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
        final val =
            double.tryParse(_splitControllers[m.id]?.text ?? '0') ?? 0.0;
        splits[m.id] = val;
        sumCheck += val;
      }

      // Allow a small epsilon for floating point math, but warn if totally off
      if ((sumCheck - totalAmount).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Splits sum (${widget.groupCurrency} $sumCheck) must equal Total (${widget.groupCurrency} $totalAmount)',
            ),
          ),
        );
        return;
      }
    }

    final navigator = Navigator.of(context);
    try {
      if (widget.expense == null) {
        await ref
            .read(expensesRepositoryProvider)
            .createExpense(
              groupId: widget.groupId,
              description: desc,
              amount: totalAmount,
              payerId: _selectedPayerId!,
              category: _selectedCategory,
              date: DateTime.now(),
              splits: splits,
            );
      } else {
        final user = ref.read(authControllerProvider).value;
        if (user != null) {
          await ref
              .read(expensesRepositoryProvider)
              .updateExpense(
                groupId: widget.groupId,
                expenseId: widget.expense!.id,
                userId: user.id,
                description: desc,
                amount: totalAmount,
                payerId: _selectedPayerId!,
                category: _selectedCategory,
                date: widget
                    .expense!
                    .date, // Keep original date or update? user didn't ask to change date.
                splits: splits,
              );
        }
      }
      if (navigator.mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
