import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../groups/data/groups_repository.dart';
import '../../home/presentation/main_screen.dart';
import '../data/auth_repository.dart';
import 'login_screen.dart';

/// Invite tokens claimed during this session. Prevents a rebuild from
/// re-claiming the same link and showing an "already a member" error.
final Set<String> _claimedInviteTokens = <String>{};

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Web invite links arrive as `/join?token=...`; on mobile the same query
    // parameter can be added to the launch URL later (no Dynamic Links).
    final inviteToken = Uri.base.queryParameters['token'];
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();

        if (inviteToken != null &&
            inviteToken.isNotEmpty &&
            !_claimedInviteTokens.contains(inviteToken)) {
          return _InviteClaimScreen(token: inviteToken, userId: user.id);
        }

        return const MainScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => const LoginScreen(),
    );
  }
}

/// Claims an invite once, then shows the main screen. Kept as a stateful
/// widget so a rebuild cannot claim the same token twice.
class _InviteClaimScreen extends ConsumerStatefulWidget {
  const _InviteClaimScreen({required this.token, required this.userId});

  final String token;
  final String userId;

  @override
  ConsumerState<_InviteClaimScreen> createState() => _InviteClaimScreenState();
}

class _InviteClaimScreenState extends ConsumerState<_InviteClaimScreen> {
  late final Future<void> _claim = _claimInvite();
  bool _reported = false;

  Future<void> _claimInvite() async {
    await ref
        .read(groupsRepositoryProvider)
        .claimInvite(widget.token, widget.userId);
    _claimedInviteTokens.add(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _claim,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (!_reported) {
            _reported = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final error = snapshot.error;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    error == null
                        ? 'Invite claimed successfully!'
                        : 'Failed to claim invite: $error',
                  ),
                  backgroundColor: error == null ? null : Colors.red,
                ),
              );
            });
          }
          return const MainScreen();
        }

        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Claiming invite...'),
              ],
            ),
          ),
        );
      },
    );
  }
}
