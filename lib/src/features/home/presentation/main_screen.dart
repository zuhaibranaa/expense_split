import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../groups/presentation/groups_list_screen.dart';
import '../../auth/presentation/profile_screen.dart';
import '../../groups/presentation/group_detail_screen.dart';
import '../../analytics/presentation/stats_screen.dart';
import '../../analytics/presentation/global_settlements_screen.dart';
import '../../groups/data/groups_repository.dart';

import '../../auth/data/auth_repository.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('EquiSplit'), centerTitle: true),
      body: groupsAsync.when(
        data: (groups) {
          final personalGroup = groups.cast<dynamic>().firstWhere(
            (g) => g.type == 'PERSONAL',
            orElse: () => null,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. Personal Expense Card (Full Width)
                if (personalGroup != null)
                  Consumer(
                    builder: (context, ref, _) {
                      final user = ref.watch(authControllerProvider).value;
                      final isPremium = user?.isPremium ?? false;

                      return _buildCard(
                        context,
                        title: 'Personal Expenses',
                        icon: Icons.person,
                        color: Colors.blueAccent,
                        isLocked: !isPremium,
                        onTap: () {
                          if (!isPremium) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Premium Feature'),
                                content: const Text(
                                  'Accessing Personal Expenses requires a premium subscription. Please upgrade to unlock.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      // TODO: Navigate to Upgrade Screen in the future
                                    },
                                    child: const Text('Upgrade'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  GroupDetailScreen(group: personalGroup),
                            ),
                          );
                        },
                        isFullWidth: true,
                      );
                    },
                  ),
                if (personalGroup != null) const SizedBox(height: 16),

                // Grid for others
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    // 2. Expense Groups
                    _buildCard(
                      context,
                      title: 'Groups',
                      icon: Icons.group,
                      color: Colors.purpleAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const GroupsListScreen(),
                          ),
                        );
                      },
                    ),

                    // 3. Global Stats
                    _buildCard(
                      context,
                      title: 'Global Stats',
                      icon: Icons.pie_chart,
                      color: Colors.orangeAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const StatsScreen(),
                          ),
                        );
                      },
                    ),

                    // 4. Global Settlements
                    _buildCard(
                      context,
                      title: 'Settlements',
                      icon: Icons.account_balance_wallet,
                      color: Colors.greenAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const GlobalSettlementsScreen(),
                          ),
                        );
                      },
                    ),

                    // 5. Profile -> Now Wallet-styled
                    _buildCard(
                      context,
                      title: 'Profile',
                      icon: Icons.person_outline,
                      color: Colors.teal, // Updated to Teal (Wallet style)
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
    bool isLocked = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: isFullWidth ? double.infinity : null,
          height: isFullWidth ? 120 : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 40, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLocked)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.lock, color: Colors.white70, size: 24),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
