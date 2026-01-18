import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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

  final Set<int> _selectedMemberIds = {};
  SplitMethod _splitMethod = SplitMethod.equal;
  final Map<int, TextEditingController> _splitControllers = {};
  bool _isInit = true;
  InterstitialAd? _interstitialAd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit && widget.expense != null) {
      _descriptionController.text = widget.expense!.description;
      _amountController.text = widget.expense!.amount.toString();
      _selectedPayerId = widget.expense!.payerId;
      _selectedCategory = widget.expense!.category;

      // Initialize selected members from existing splits
      if (widget.expense!.splits.isNotEmpty) {
        _selectedMemberIds.addAll(
          widget.expense!.splits.map((s) => s.memberId),
        );
      }
    }
    if (_isInit) {
      _loadAd();
    }
    _isInit = false;
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    for (var c in _splitControllers.values) {
      c.dispose();
    }
    for (var f in _splitFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersFutureProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('New Expense')),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('Add people to the group first!'));
          }

          // Default initialization
          if (_selectedPayerId == null) {
            if (widget.expense == null) {
              // New Expense: Select all by default
              if (_selectedMemberIds.isEmpty) {
                _selectedMemberIds.addAll(members.map((m) => m.id));
              }
              _selectedPayerId = members.first.id;
            } else {
              // Editing: _selectedMemberIds already handled in didChangeDependencies
              // But we need to ensure at least one is selected? or just fallback to all if empty which shouldn't happen for valid expense
              if (_selectedMemberIds.isEmpty) {
                _selectedMemberIds.addAll(members.map((m) => m.id));
              }
            }

            // Initialize controllers + method
            if (widget.expense != null) {
              _selectedPayerId = widget.expense!.payerId;

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

              for (var m in members) {
                final split = widget.expense!.splits.firstWhere(
                  (s) => s.memberId == m.id,
                  orElse: () => ExpenseSplit(id: -1, memberId: m.id, amount: 0),
                );
                final c = TextEditingController(
                  text: split.amount.toStringAsFixed(2),
                );
                c.addListener(() => _onSplitAmountChanged(m.id, members));
                _splitControllers[m.id] = c;
              }
            } else {
              // New Expense Controllers
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
                  onChanged: (val) {
                    setState(
                      () {},
                    ); // Rebuild to update exact/equal calculations if needed
                  },
                ),
                const SizedBox(height: 16),

                // Payer
                DropdownButtonFormField<int>(
                  initialValue: _selectedPayerId,
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
                  initialValue: _selectedCategory,
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

                // Split With Selection
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Split with'),
                  subtitle: Text(
                    _selectedMemberIds.length == members.length
                        ? 'All (${members.length})'
                        : '${_selectedMemberIds.length} people selected',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showMemberSelectionDialog(members),
                ),
                const Divider(),
                const SizedBox(height: 16),

                // Split Method Toggle
                SegmentedButton<SplitMethod>(
                  segments: const [
                    ButtonSegment(
                      value: SplitMethod.equal,
                      label: Text('Equal'),
                    ),
                    ButtonSegment(
                      value: SplitMethod.exact,
                      label: Text('Exact'),
                    ),
                  ],
                  selected: {_splitMethod},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _splitMethod = newSelection.first;
                      if (_splitMethod == SplitMethod.exact) {
                        _recalculateExactSplits(members);
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

  void _recalculateExactSplits(List<Member> members) {
    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    final activeMembers = members
        .where((m) => _selectedMemberIds.contains(m.id))
        .toList();

    if (totalAmount > 0 && activeMembers.isNotEmpty) {
      final baseShare =
          (totalAmount / activeMembers.length * 100).floor() / 100.0;
      double remainder = totalAmount - (baseShare * activeMembers.length);

      _manuallyEditedMemberIds.clear();
      _isProgrammaticUpdate = true;

      // Reset all controllers first to 0
      for (var m in members) {
        _splitControllers[m.id]?.text = "0.00";
      }

      for (var i = 0; i < activeMembers.length; i++) {
        double share = baseShare;
        if (i < (remainder * 100).round()) {
          share += 0.01;
        }
        _splitControllers[activeMembers[i].id]?.text = share.toStringAsFixed(2);
      }
      _isProgrammaticUpdate = false;
    }
  }

  Future<void> _showMemberSelectionDialog(List<Member> members) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final allSelected = _selectedMemberIds.length == members.length;

            return AlertDialog(
              title: const Text('Split with'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: _buildMemberStack(members),
                      value: allSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedMemberIds.addAll(members.map((m) => m.id));
                          } else {
                            _selectedMemberIds.clear();
                          }
                        });
                        this.setState(() {});
                      },
                    ),
                    ...members.map((m) {
                      return CheckboxListTile(
                        title: Text(m.name),
                        secondary: CircleAvatar(
                          backgroundImage: m.avatarUrl != null
                              ? NetworkImage(m.avatarUrl!)
                              : null,
                          child: m.avatarUrl == null
                              ? Text(
                                  m.name.isNotEmpty
                                      ? m.name[0].toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        value: _selectedMemberIds.contains(m.id),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedMemberIds.add(m.id);
                            } else {
                              _selectedMemberIds.remove(m.id);
                            }
                          });
                          this.setState(() {});
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Recalculate if in Exact mode when closing
                    if (_splitMethod == SplitMethod.exact) {
                      _recalculateExactSplits(members);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEqualSplitView(List<Member> members) {
    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    final count = _selectedMemberIds.length;
    final perPerson = count > 0 ? totalAmount / count : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Split equally between $count people'),
            const SizedBox(height: 4),
            Text(
              '${widget.groupCurrency} ${perPerson.toStringAsFixed(2)} / person',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // List who is included
            Wrap(
              spacing: 8,
              children: members
                  .where((m) => _selectedMemberIds.contains(m.id))
                  .map((m) {
                    return Chip(
                      label: Text(m.name, style: const TextStyle(fontSize: 10)),
                    );
                  })
                  .toList(),
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

    // If changing a member that isn't selected, maybe auto-select them?
    // For now, let's assume UI handles visibility, but logic needs safety.
    if (!_selectedMemberIds.contains(changedMemberId)) return;

    setState(() {
      _manuallyEditedMemberIds.add(changedMemberId);
    });

    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;

    final activeMembers = members
        .where((m) => _selectedMemberIds.contains(m.id))
        .toList();

    // Check if all active members are manually edited
    final allEdited = activeMembers.every(
      (m) => _manuallyEditedMemberIds.contains(m.id),
    );

    if (allEdited) {
      // All manual: Update total from sum of splits
      double sum = 0.0;
      for (var m in activeMembers) {
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

      for (var m in activeMembers) {
        if (_manuallyEditedMemberIds.contains(m.id)) {
          manualSum +=
              double.tryParse(_splitControllers[m.id]?.text ?? '0') ?? 0.0;
        } else {
          uneditedMembers.add(m);
        }
      }

      double remaining = totalAmount - manualSum;
      if (remaining < 0) {
        remaining = 0;
      }

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
    // Ensure controllers and focus nodes exist and have listeners
    for (var m in members) {
      if (!_splitControllers.containsKey(m.id)) {
        final c = TextEditingController(text: '0.00');
        c.addListener(() => _onSplitAmountChanged(m.id, members));
        _splitControllers[m.id] = c;
      }

      if (!_splitFocusNodes.containsKey(m.id)) {
        final fn = FocusNode();
        fn.addListener(() {
          if (fn.hasFocus) {
            // Store previous value and clear on focus
            _tempSplitValues[m.id] = _splitControllers[m.id]?.text ?? '0.00';
            _splitControllers[m.id]?.clear();
          } else {
            // On blur, if empty, restore previous value
            if (_splitControllers[m.id]?.text.isEmpty ?? true) {
              _splitControllers[m.id]?.text = _tempSplitValues[m.id] ?? '0.00';
            }
          }
        });
        _splitFocusNodes[m.id] = fn;
      }
    }

    // Only show members that are selected
    final activeMembers = members
        .where((m) => _selectedMemberIds.contains(m.id))
        .toList();

    return Column(
      children: activeMembers.map((member) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(member.name)),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _splitControllers[member.id],
                  focusNode: _splitFocusNodes[member.id],
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

  final Map<int, FocusNode> _splitFocusNodes = {};
  final Map<int, String> _tempSplitValues = {};

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

    // Filter to ensure only valid, currently existing members are included
    final activeMembers = members
        .where((m) => _selectedMemberIds.contains(m.id))
        .toList();

    if (activeMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one person to split with'),
        ),
      );
      return;
    }

    // Calculate Splits
    final Map<int, double> splits = {};
    if (_splitMethod == SplitMethod.equal) {
      final splitAmount = totalAmount / activeMembers.length;
      for (var m in activeMembers) {
        splits[m.id] = splitAmount;
      }
    } else {
      // Exact split logic
      double sumCheck = 0.0;
      for (var m in activeMembers) {
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
            .read(expensesFutureProvider(widget.groupId).notifier)
            .createExpense(
              description: desc,
              amount: totalAmount,
              payerId: _selectedPayerId!,
              category: _selectedCategory,
              date: DateTime.now(),
              splits: splits,
            );
        if (_interstitialAd != null) {
          _interstitialAd!.show();
        } else {
          if (navigator.mounted) navigator.pop();
        }
      } else {
        final user = ref.read(authControllerProvider).value;
        if (user != null) {
          await ref
              .read(expensesFutureProvider(widget.groupId).notifier)
              .updateExpense(
                expenseId: widget.expense!.id,
                userId: user.id,
                description: desc,
                amount: totalAmount,
                payerId: _selectedPayerId!,
                category: _selectedCategory,
                date: widget.expense!.date,
                splits: splits,
              );
        }
        if (navigator.mounted) navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildMemberStack(List<Member> membersToDisplay) {
    if (membersToDisplay.isEmpty) return const SizedBox();

    const double overlap = 10.0;
    const double avatarSize = 30.0;
    const int maxVisible = 5;

    final visibleCount = membersToDisplay.length > maxVisible
        ? maxVisible
        : membersToDisplay.length;
    final remainingCount = membersToDisplay.length - visibleCount;

    return SizedBox(
      height: avatarSize,
      child: Stack(
        children: [
          ...List.generate(visibleCount, (index) {
            return Positioned(
              left: index * (avatarSize - overlap),
              child: CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: (avatarSize / 2) - 1,
                  backgroundImage: membersToDisplay[index].avatarUrl != null
                      ? NetworkImage(membersToDisplay[index].avatarUrl!)
                      : null,
                  child: membersToDisplay[index].avatarUrl == null
                      ? Text(
                          membersToDisplay[index].name.isNotEmpty
                              ? membersToDisplay[index].name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 10),
                        )
                      : null,
                ),
              ),
            );
          }),
          if (remainingCount > 0)
            Positioned(
              left: visibleCount * (avatarSize - overlap),
              child: CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: (avatarSize / 2) - 1,
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.black,
                  child: Text(
                    '+$remainingCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _loadAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // Test ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  if (mounted) Navigator.of(context).pop();
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  ad.dispose();
                  if (mounted) Navigator.of(context).pop();
                },
              );
        },
        onAdFailedToLoad: (err) {
          debugPrint('Failed to load an interstitial ad: ${err.message}');
        },
      ),
    );
  }
}
