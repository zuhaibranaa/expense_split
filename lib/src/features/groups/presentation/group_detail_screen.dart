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
    final isPersonal = group.type == 'PERSONAL';

    // Tabs configuration
    final tabs = [
      const Tab(text: 'Expenses'),
      if (!isPersonal) const Tab(text: 'Payments'),
      if (!isPersonal) const Tab(text: 'Balances'),
      if (!isPersonal) const Tab(text: 'People'),
      const Tab(text: 'Stats'),
      const Tab(text: 'Settings'),
    ];

    final children = [
      ExpensesListScreen(
        groupId: group.id,
        groupCurrency: group.currency,
        isPersonal: isPersonal,
      ),
      if (!isPersonal)
        PaymentsListScreen(groupId: group.id, groupCurrency: group.currency),
      if (!isPersonal)
        BalancesScreen(groupId: group.id, groupCurrency: group.currency),
      if (!isPersonal) MembersListView(groupId: group.id),
      GroupStatsScreen(groupId: group.id, groupCurrency: group.currency),
      GroupSettingsScreen(group: group),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(group.name),
              actions: [
                _FilterActionButton(groupId: group.id, isPersonal: isPersonal),
              ],
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
                tabs: tabs,
              ),
            ),
            body: TabBarView(children: children),
          );
        },
      ),
    );
  }
}

class _FilterActionButton extends StatefulWidget {
  final int groupId;
  final bool isPersonal;

  const _FilterActionButton({required this.groupId, this.isPersonal = false});

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

    // Logic depends on tab indices.
    // If Personal: [Expenses, Stats, Settings] -> Indices: 0, 1, 2
    // If Regular: [Exp, Pay, Bal, Ppl, Stats, Sets] -> Indices: 0, 1, 2, 3, 4, 5

    bool isStats = false;
    bool isSettings = false;
    bool isPeople = false;
    bool isBalances = false;

    if (widget.isPersonal) {
      if (index == 1) isStats = true;
      if (index == 2) isSettings = true;
    } else {
      if (index == 4) isStats = true;
      if (index == 5) isSettings = true;
      if (index == 3) isPeople = true;
      if (index == 2) isBalances = true;
    }

    // Hide on People and Settings
    if (isPeople || isSettings) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.filter_list_rounded),
      onPressed: () {
        // Configure modal based on tab
        final showSimplify = isBalances;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => FilterModal(
            groupId: widget.groupId,
            showDateFilter: true, // Always show date
            showSimplifyDebts: showSimplify,
            showMemberFilter:
                !isStats &&
                !widget.isPersonal, // Hide member filter on Stats AND Personal
            useMonthPicker: isStats || isBalances,
          ),
        );
      },
    );
  }
}
