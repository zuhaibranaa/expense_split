import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    // Show error if login fails
    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${next.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet, size: 80, color: Color(0xFF00E5FF)),
            const SizedBox(height: 24),
            Text('SettleUp', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            const Text('Split expenses effortlessly'),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: isLoading ? null : () {
                // Mock Login
                ref.read(authControllerProvider.notifier).login('demo@example.com', 'Demo User');
              },
              icon: isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.login),
              label: Text(isLoading ? 'Signing in...' : 'Sign in with Google (Simulated)'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '(Mock OAuth: Logs in as "Demo User")',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
