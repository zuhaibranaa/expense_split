import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import 'login_screen.dart';
import '../../home/presentation/main_screen.dart';
import '../../groups/data/groups_repository.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check for invite token in URL (Simulated Deep Link for Web/Simple Mobile)
    // Note: On mobile, this requires deep link config (Universal Links), 
    // but for this clone we assume standard launch or web usage.
    // If we receive "token" query param, we try to claim it.
    
    // We can't easily get query params here without GoRouter state or parsing Uri.base
    // For this simple implementation, we check Uri.base on build.
    
    final uri = Uri.base;
    final inviteToken = uri.queryParameters['token'];

    if (inviteToken != null) {
      // Allow the auth state to settle, then claim. 
      // Actually, we should only claim if logged in.
    }

    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          if (inviteToken != null) {
            return FutureBuilder(
              future: _claimInvite(ref, inviteToken, user.id, context),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                   // Clear query params from URL if possible or just show MainScreen
                   return const MainScreen(); 
                }
                return const Scaffold(body: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Claiming invite...'),
                  ],
                )));
              },
            );
          }
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Future<void> _claimInvite(WidgetRef ref, String token, int userId, BuildContext context) async {
    try {
      // Avoid double claiming if rebuilt
      // In a real app we'd use a dedicated provider/state for this.
      await ref.read(groupsRepositoryProvider).claimInvite(token, userId);
      
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite claimed successfully!')));
      }
    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to claim invite: $e'), backgroundColor: Colors.red));
      }
    }
    // Modify history/URL if on web? No easy way without Router.
    // We just return, MainScreen will render. 
  }
}
