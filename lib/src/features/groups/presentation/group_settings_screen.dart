import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../categories/presentation/category_management_screen.dart';
import 'package:currency_picker/currency_picker.dart';
import '../domain/group_model.dart';
import '../data/groups_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../people/data/members_repository.dart';
import '../../people/domain/member_model.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final Group group;

  const GroupSettingsScreen({super.key, required this.group});

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _isLoading = false;

  Future<Member?> _getCurrentUserMember() async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return null;

    final members = await ref.read(
      membersFutureProvider(widget.group.id).future,
    );
    return members.firstWhere(
      (m) => m.userId == user.id,
      orElse: () => Member(
        id: -1,
        groupId: widget.group.id,
        name: '',
        userId: null,
        isAdmin: 0,
      ),
    );
  }

  Future<bool> _isCurrentUserAdmin() async {
    final member = await _getCurrentUserMember();
    return member?.isAdmin == 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Group Info Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Group Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.group),
                            title: const Text('Group Name'),
                            subtitle: Text(widget.group.name),
                          ),
                          ListTile(
                            leading: const Icon(Icons.attach_money),
                            title: const Text('Currency'),
                            subtitle: Text(widget.group.currency),
                            trailing: FutureBuilder<bool>(
                              future: _isCurrentUserAdmin(),
                              builder: (context, snapshot) {
                                if (snapshot.data == true) {
                                  return IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        _showChangeCurrencyDialog(),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.category),
                            title: const Text('Manage Categories'),
                            subtitle: const Text('Add or remove categories'),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CategoryManagementScreen(
                                        groupId: widget.group.id,
                                      ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Personal Group Actions (only for PERSONAL groups)
                  if (widget.group.type == 'PERSONAL') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal Group Actions',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Manage your personal balance and sync data from group expenses.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => _showSyncDialog(context),
                              icon: const Icon(Icons.sync),
                              label: const Text('Sync from Expenses'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => _showResetBalanceDialog(context),
                              icon: const Icon(
                                Icons.restart_alt,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Reset Balance',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Danger Zone (non-personal groups, admin only)
                  FutureBuilder<bool>(
                    future: _isCurrentUserAdmin(),
                    builder: (context, snapshot) {
                      if (snapshot.data == true &&
                          widget.group.type != 'PERSONAL') {
                        return Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Danger Zone',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(color: Colors.red),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () => _showDeleteGroupDialog(),
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Delete Group',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Currency ─────────────────────────────────────────────────────────────

  void _showChangeCurrencyDialog() {
    showCurrencyPicker(
      context: context,
      showFlag: true,
      showCurrencyName: true,
      showCurrencyCode: true,
      onSelect: (Currency currency) async {
        setState(() => _isLoading = true);
        try {
          final user = ref.read(authControllerProvider).value;
          if (user == null) return;

          await ref
              .read(groupsListProvider.notifier)
              .updateGroup(widget.group.id, currency: currency.code);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Currency changed to ${currency.code}')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      favorite: ['USD', 'EUR', 'GBP', 'INR', 'PKR'],
    );
  }

  // ─── Reset Balance ────────────────────────────────────────────────────────

  void _showResetBalanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Balance'),
        content: const Text(
          'This will set your balance to 0 and permanently delete ALL your personal expenses and income entries.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _doResetBalance();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _doResetBalance() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(groupsRepositoryProvider).resetPersonalBalance();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reset job dispatched — balance will be cleared shortly.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Sync from Expenses ───────────────────────────────────────────────────

  void _showSyncDialog(BuildContext context) {
    final now = DateTime.now();
    DateTime startMonth = DateTime(now.year, now.month, 1);
    DateTime endMonth = DateTime(now.year, now.month, 1);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            String formatMonth(DateTime dt) {
              const months = [
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec',
              ];
              return '${months[dt.month - 1]} ${dt.year}';
            }

            Future<void> pickMonth({
              required bool isStart,
              required DateTime current,
            }) async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: current,
                firstDate: DateTime(2020),
                lastDate: now,
                helpText: isStart ? 'Select start month' : 'Select end month',
                initialDatePickerMode: DatePickerMode.year,
              );
              if (picked == null) return;
              final month = DateTime(picked.year, picked.month, 1);
              setDialogState(() {
                if (isStart) {
                  startMonth = month;
                  if (endMonth.isBefore(startMonth)) endMonth = startMonth;
                } else {
                  endMonth = month;
                  if (startMonth.isAfter(endMonth)) startMonth = endMonth;
                }
              });
            }

            return AlertDialog(
              title: const Text('Sync from Expenses'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the month range to sync your personal data from group expenses and payments.',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'From',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            OutlinedButton(
                              onPressed: () =>
                                  pickMonth(isStart: true, current: startMonth),
                              child: Text(formatMonth(startMonth)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'To',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            OutlinedButton(
                              onPressed: () =>
                                  pickMonth(isStart: false, current: endMonth),
                              child: Text(formatMonth(endMonth)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    final start =
                        '${startMonth.year}-${startMonth.month.toString().padLeft(2, '0')}-01';
                    // Last day of end month
                    final lastDay = DateTime(
                      endMonth.year,
                      endMonth.month + 1,
                      0,
                    );
                    final end =
                        '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
                    await _doSync(startDate: start, endDate: end);
                  },
                  child: const Text('Sync'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _doSync({
    required String startDate,
    required String endDate,
  }) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(groupsRepositoryProvider)
          .syncPersonalFromExpenses(startDate: startDate, endDate: endDate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sync job dispatched — data will be updated shortly.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Delete Group ─────────────────────────────────────────────────────────

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone and will delete all expenses and members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              try {
                final user = ref.read(authControllerProvider).value;
                if (user == null) return;

                await ref
                    .read(groupsRepositoryProvider)
                    .deleteGroup(widget.group.id, user.id);

                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
