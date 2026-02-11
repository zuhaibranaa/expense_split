import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/group_model.dart';
import '../../people/presentation/members_list_view.dart';
import '../../expenses/presentation/expenses_list_screen.dart';
import '../../expenses/presentation/payments_list_screen.dart';
import '../../expenses/presentation/balances_screen.dart';
import '../../analytics/presentation/group_stats_screen.dart';
import 'group_settings_screen.dart';
import 'package:equisplit/src/shared/presentation/widgets/filter_modal.dart';

class GroupDetailScreen extends ConsumerWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6, // Changed from 5 to 6
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(group.name),
              actions: [_FilterActionButton(groupId: group.id)],
              bottom: TabBar(
                isScrollable: true,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(width: 3.0, color: Color(0xFF00E5FF)),
                  insets: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF00E5FF),
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Expenses'),
                  Tab(text: 'Payments'),
                  Tab(text: 'Balances'),
                  Tab(text: 'People'),
                  Tab(text: 'Stats'),
                  Tab(text: 'Settings'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                ExpensesListScreen(
                  groupId: group.id,
                  groupCurrency: group.currency,
                ),
                PaymentsListScreen(
                  groupId: group.id,
                  groupCurrency: group.currency,
                ),
                BalancesScreen(
                  groupId: group.id,
                  groupCurrency: group.currency,
                ),
                MembersListView(groupId: group.id),
                GroupStatsScreen(
                  groupId: group.id,
                  groupCurrency: group.currency,
                ),
                GroupSettingsScreen(group: group), // New settings screen
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterActionButton extends StatefulWidget {
  final int groupId;

  const _FilterActionButton({required this.groupId});

  @override
  State<_FilterActionButton> createState() => _FilterActionButtonState();
}

class _FilterActionButtonState extends State<_FilterActionButton> {
  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (controller != _tabController) {
      _tabController?.removeListener(_handleTabChange);
      _tabController = controller;
      _tabController?.addListener(_handleTabChange);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) return const SizedBox.shrink();

    final index = _tabController!.index;

    // Hide on People (3) and Settings (5)
    if (index == 3 || index == 5) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.filter_list_rounded),
      onPressed: () {
        // Configure modal based on tab
        // 0: Expenses, 1: Payments - Standard
        // 2: Balances - No Date, Simplify Toggle
        // 4: Stats - Month Picker, No Member Filter

        final showDate = index != 2; // Hide date on Balances
        final showSimplify = index == 2; // Show simplify on Balances
        final isStats = index == 4;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => FilterModal(
            groupId: widget.groupId,
            showDateFilter: showDate,
            showSimplifyDebts: showSimplify,
            showMemberFilter: !isStats, // Hide member filter on Stats
            useMonthPicker: isStats, // Use month picker on Stats
          ),
        );
      },
    );
  }
}
