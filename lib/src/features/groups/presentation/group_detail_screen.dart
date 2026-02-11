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
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list_rounded),
                  onPressed: () {
                    // Get current tab index to determine if we show date filter
                    final tabController = DefaultTabController.of(context);
                    final index = tabController.index;
                    // Balances is at index 2 (Expenses=0, Payments=1, Balances=2)
                    final showDate = index != 2;

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => FilterModal(
                        groupId: group.id,
                        showDateFilter: showDate,
                        showSimplifyDebts:
                            !showDate, // Only show on Balances (where showDate is false)
                      ),
                    );
                  },
                ),
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
