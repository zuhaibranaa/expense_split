import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expenses_repository.dart';
import '../../people/data/members_repository.dart';
import '../../people/domain/member_model.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/expense_model.dart';
import '../../../shared/utils/currency_utils.dart';
import 'package:equisplit/src/shared/presentation/widgets/user_avatar.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../cash_inflows/data/cash_inflow_repository.dart';
import '../../cash_inflows/domain/cash_inflow_model.dart';

enum SplitMethod { equal, exact }

class AddExpenseScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupCurrency; // Add group currency
  final bool isPersonal;

  final Expense? expense;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.groupCurrency,
    this.isPersonal = false,
    this.isIncome = false,
    this.expense,
    this.inflow,
  });

  final bool isIncome;
  final CashInflow? inflow;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  int? _selectedPayerId;
  bool _isMultiplePayers = false;
  final Map<int, TextEditingController> _payerControllers = {};
  final Set<int> _selectedPayerIds = {};
  String? _selectedCategory;
  List<Category> _categories = [];

  final Set<int> _selectedMemberIds = {};
  SplitMethod _splitMethod = SplitMethod.equal;
  final Map<int, TextEditingController> _splitControllers = {};
  bool _isInit = true;
  bool _isLoading = false;
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

      // Initialize payers
      if (widget.expense!.payments.length > 1) {
        _isMultiplePayers = true;
        for (var p in widget.expense!.payments) {
          _selectedPayerIds.add(p.memberId);
          _payerControllers[p.memberId] = TextEditingController(
            text: p.amount.toString(),
          );
          _payerControllers[p.memberId]!.addListener(_onPaymentAmountChanged);
        }
      } else if (widget.expense!.payments.isNotEmpty) {
        // Single payer from payments list
        _selectedPayerId = widget.expense!.payments.first.memberId;
      }

      // Init Listeners
      _initPaymentListeners();
      _initPaymentListeners();
    } else if (_isInit && widget.inflow != null) {
      _descriptionController.text = widget.inflow!.description;
      _amountController.text = widget.inflow!.amount.toString();
      _selectedCategory = widget.inflow!.category;
      // Inflow typically has no payers/splits in this UI context
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
    for (var c in _payerControllers.values) {
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
    final categoriesAsync = ref.watch(groupCategoriesProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isIncome ? 'New Income' : 'New Expense'),
      ),
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
              _selectedPayerId =
                  members
                      .where(
                        (m) =>
                            m.userId ==
                            ref.read(authRepositoryProvider).currentUser?.id,
                      )
                      .firstOrNull
                      ?.id ??
                  members.first.id;
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
                    labelText:
                        'Total Amount (${CurrencyUtils.getSymbol(widget.groupCurrency)})',
                    prefixIcon: const Icon(Icons.attach_money),
                    helperText: 'Currency: ${widget.groupCurrency}',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (val) {
                    _onTotalAmountChanged(members);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),

                // Payer (Hide if Income)
                if (!widget.isIncome && !widget.isPersonal) ...[
                  if (!_isMultiplePayers)
                    DropdownButtonFormField<int>(
                      initialValue: _selectedPayerId,
                      decoration: const InputDecoration(
                        labelText: 'Paid By',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: -1,
                          child: Text("Multiple people"),
                        ),
                        ...members.map((m) {
                          var text = m.name;
                          if (m.userId ==
                              ref
                                  .read(authRepositoryProvider)
                                  .currentUser
                                  ?.id) {
                            text = "Me";
                          }
                          return DropdownMenuItem(
                            value: m.id,
                            child: Text(text),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val == -1) {
                          setState(() {
                            _isMultiplePayers = true;
                            // Initialize selected payers (default to none or handle in dialog)
                            // If current user is present, maybe select them?
                            final currentUser = ref
                                .read(authRepositoryProvider)
                                .currentUser;
                            final myMember = members
                                .where((m) => m.userId == currentUser?.id)
                                .firstOrNull;
                            if (myMember != null) {
                              _selectedPayerIds.add(myMember.id);
                            }

                            // Initialize controllers for ALL members just in case, but only show selected
                            // Initialize controllers for ALL members just in case, but only show selected
                            for (var m in members) {
                              _getOrCreatePayerController(m.id);
                            }

                            // Auto open dialog
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _showPayerSelectionDialog(members);
                            });
                          });
                        } else {
                          setState(() => _selectedPayerId = val);
                        }
                      },
                    ),

                  if (_isMultiplePayers) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Paid by multiple people'),
                      subtitle: Text(
                        _selectedPayerIds.length == members.length
                            ? 'All (${members.length})'
                            : '${_selectedPayerIds.length} people selected',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isMultiplePayers = false;
                                _selectedPayerId = members.first.id;
                                _selectedPayerIds.clear();
                              });
                            },
                            child: const Text("Reset"),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                      onTap: () => _showPayerSelectionDialog(members),
                    ),

                    ...members.where((m) => _selectedPayerIds.contains(m.id)).map((
                      m,
                    ) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            UserAvatar(
                              avatarUrl: m.avatarUrl,
                              name: m.name,
                              radius: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(m.name)),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _getOrCreatePayerController(m.id),
                                decoration: InputDecoration(
                                  prefixText:
                                      '${CurrencyUtils.getSymbol(widget.groupCurrency)} ',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.all(8),
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 16),
                ],

                // Category
                categoriesAsync.when(
                  data: (categories) {
                    if (_categories.isEmpty && categories.isNotEmpty) {
                      _categories = categories;
                      if (_selectedCategory == null ||
                          !_categories.any(
                            (c) => c.name == _selectedCategory,
                          )) {
                        _selectedCategory =
                            'General'; // Default fallback? Or first category?
                        if (categories.any((c) => c.name == 'General')) {
                          _selectedCategory = 'General';
                        } else if (categories.isNotEmpty) {
                          _selectedCategory = categories.first.name;
                        }
                      }
                    } else if (categories.isEmpty) {
                      // Fallback if no categories found (shouldn't happen if seeded)
                      return const SizedBox();
                    }

                    return DropdownButtonFormField<String>(
                      key: ValueKey(_selectedCategory),
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(
                          value: c.name,
                          child: Row(
                            children: [
                              if (c.icon != null) ...[
                                Text(c.icon!),
                                SizedBox(width: 8),
                              ],
                              Text(c.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCategory = val);
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Error loading categories: $e'),
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 24),

                if (!widget.isIncome && !widget.isPersonal) ...[
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
                ],

                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isLoading ? null : () => _submit(members),
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _isLoading
                        ? 'Saving...'
                        : (widget.expense == null && widget.inflow == null
                              ? (widget.isIncome
                                    ? 'Save Income'
                                    : 'Save Expense')
                              : (widget.inflow != null
                                    ? 'Update Income'
                                    : 'Update Expense')),
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
                        secondary: UserAvatar(
                          radius: 20,
                          avatarUrl: m.avatarUrl,
                          name: m.name,
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

  Future<void> _showPayerSelectionDialog(List<Member> members) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final allSelected = _selectedPayerIds.length == members.length;

            return AlertDialog(
              title: const Text('Paid by'),
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
                            _selectedPayerIds.addAll(members.map((m) => m.id));
                          } else {
                            _selectedPayerIds.clear();
                          }
                        });
                        this.setState(() {});
                      },
                    ),
                    ...members.map((m) {
                      return CheckboxListTile(
                        title: Text(m.name),
                        secondary: UserAvatar(
                          radius: 20,
                          avatarUrl: m.avatarUrl,
                          name: m.name,
                        ),
                        value: _selectedPayerIds.contains(m.id),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedPayerIds.add(m.id);
                            } else {
                              _selectedPayerIds.remove(m.id);
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
                  onPressed: () => Navigator.pop(context),
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
              '${CurrencyUtils.getSymbol(widget.groupCurrency)} ${perPerson.toStringAsFixed(2)} / person',
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

  void _initPaymentListeners() {
    // Logic moved to _getOrCreatePayerController to ensure listeners are added on creation
  }

  void _onTotalAmountChanged(List<Member> members) {
    if (_isProgrammaticUpdate) return;

    if (_isMultiplePayers && _selectedPayerIds.isNotEmpty) {
      final total = double.tryParse(_amountController.text) ?? 0.0;
      final count = _selectedPayerIds.length;
      if (count > 0 && total > 0) {
        final share = (total / count * 100).floor() / 100.0;
        final remainder = total - (share * count);

        _isProgrammaticUpdate = true;

        int i = 0;
        for (var id in _selectedPayerIds) {
          double amount = share;
          if (i < (remainder * 100).round()) {
            amount += 0.01;
          }

          if (!_payerControllers.containsKey(id)) {
            _payerControllers[id] = TextEditingController(text: "0.00");
            _payerControllers[id]!.addListener(_onPaymentAmountChanged);
          }

          _payerControllers[id]!.text = amount.toStringAsFixed(2);
          i++;
        }
        _isProgrammaticUpdate = false;
      }
    }
  }

  void _onPaymentAmountChanged() {
    if (_isProgrammaticUpdate) return;
    if (!_isMultiplePayers) return;

    double sum = 0.0;
    for (var id in _selectedPayerIds) {
      sum += double.tryParse(_payerControllers[id]?.text ?? "0") ?? 0.0;
    }

    _isProgrammaticUpdate = true;
    _amountController.text = sum.toStringAsFixed(2);
    _isProgrammaticUpdate = false;

    setState(() {});
  }

  TextEditingController _getOrCreatePayerController(int memberId) {
    if (!_payerControllers.containsKey(memberId)) {
      final c = TextEditingController(text: '0.00');
      c.addListener(_onPaymentAmountChanged);
      _payerControllers[memberId] = c;
    }
    return _payerControllers[memberId]!;
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
                    prefixText:
                        '${CurrencyUtils.getSymbol(widget.groupCurrency)} ',
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

    if (desc.isEmpty || totalAmount == null || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in valid description and amount'),
        ),
      );
      return;
    }

    final bool isIncomeMode = widget.isIncome || widget.inflow != null;

    // Expense-only validation (skip for income)
    if (!isIncomeMode) {
      if (!_isMultiplePayers && _selectedPayerId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a payer')));
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
    }

    // Calculate Payments & Splits (expense only)
    Map<int, double>? payments;
    int? finalPayerId = _selectedPayerId;
    final Map<int, double> splits = {};

    if (!isIncomeMode) {
      final activeMembers = members
          .where((m) => _selectedMemberIds.contains(m.id))
          .toList();

      if (_isMultiplePayers) {
        double paymentsSum = 0.0;
        final Map<int, double> tempPayments = {};

        for (var m in members) {
          if (!_selectedPayerIds.contains(m.id)) continue;

          final val =
              double.tryParse(_payerControllers[m.id]?.text ?? '0') ?? 0.0;
          if (val > 0) {
            tempPayments[m.id] = val;
            paymentsSum += val;
          }
        }

        if ((paymentsSum - totalAmount).abs() > 0.05) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payments sum (${CurrencyUtils.getSymbol(widget.groupCurrency)} $paymentsSum) must equal Total (${CurrencyUtils.getSymbol(widget.groupCurrency)} $totalAmount)',
              ),
            ),
          );
          return;
        }

        if (tempPayments.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter at least one payment')),
          );
          return;
        }

        payments = tempPayments;
        finalPayerId = tempPayments.keys.first;
      }

      // Calculate Splits
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

        if ((sumCheck - totalAmount).abs() > 0.05) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Splits sum (${CurrencyUtils.getSymbol(widget.groupCurrency)} $sumCheck) must equal Total (${CurrencyUtils.getSymbol(widget.groupCurrency)} $totalAmount)',
              ),
            ),
          );
          return;
        }
      }
    }

    final navigator = Navigator.of(context);
    setState(() => _isLoading = true);
    try {
      if (isIncomeMode) {
        // --- INFLOW LOGIC ---
        if (widget.inflow == null) {
          // Create Inflow
          final user = ref.read(authRepositoryProvider).currentUser;
          final currency = user?.defaultCurrency ?? widget.groupCurrency;
          await ref
              .read(cashInflowRepositoryProvider)
              .createInflow(
                amount: totalAmount,
                currencyCode: currency,
                category: _selectedCategory ?? 'Income',
                description: desc,
                date: DateTime.now(),
              );
          await ref.read(authControllerProvider.notifier).reloadUser();
          if (!mounted) return;
          if (_interstitialAd != null) {
            _interstitialAd!.show();
          } else {
            if (navigator.mounted) navigator.pop();
          }
        } else {
          // Update Inflow
          await ref
              .read(cashInflowRepositoryProvider)
              .updateInflow(
                id: widget.inflow!.id,
                amount: totalAmount,
                currencyCode: widget.inflow!.currencyCode,
                category: _selectedCategory ?? 'Income',
                description: desc,
                date: widget.inflow!.date,
              );
          await ref.read(authControllerProvider.notifier).reloadUser();
          if (navigator.mounted) navigator.pop();
        }
      } else {
        // --- EXPENSE LOGIC ---
        if (widget.expense == null) {
          await ref
              .read(expensesFutureProvider(widget.groupId).notifier)
              .createExpense(
                description: desc,
                amount: totalAmount,
                payerId: finalPayerId!,
                category: _selectedCategory ?? 'General',
                date: DateTime.now(),
                splits: splits,
                payments: payments,
              );
          // Refresh User to update balance
          await ref.read(authControllerProvider.notifier).reloadUser();
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
                  payerId: finalPayerId!,
                  category: _selectedCategory ?? 'General',
                  date: widget.expense!.date,
                  splits: splits,
                  payments: payments,
                );
            // Refresh User to update balance
            await ref.read(authControllerProvider.notifier).reloadUser();
          }
          if (navigator.mounted) navigator.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
