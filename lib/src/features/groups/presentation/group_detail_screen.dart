import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/group_model.dart';
import '../../people/presentation/members_list_view.dart';
import '../../expenses/presentation/expenses_list_screen.dart';
import '../../expenses/presentation/balances_screen.dart';
import 'group_settings_screen.dart';

class GroupDetailScreen extends ConsumerWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,  // Changed from 3 to 4
      child: Scaffold(
        appBar: AppBar(
          title: Text(group.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expenses'),
              Tab(text: 'Balances'),
              Tab(text: 'People'),
              Tab(text: 'Settings'),  // New tab
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ExpensesListScreen(groupId: group.id, groupCurrency: group.currency),
            BalancesScreen(groupId: group.id, groupCurrency: group.currency),
            MembersListView(groupId: group.id),
            GroupSettingsScreen(group: group),  // New settings screen
          ],
        ),
      ),
    );
  }
}
