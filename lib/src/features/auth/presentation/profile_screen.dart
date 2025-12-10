import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_picker/currency_picker.dart';
import '../data/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Not logged in'));
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null ? Text(user.name[0]) : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(user.name, style: Theme.of(context).textTheme.headlineSmall)),
              Center(child: Text(user.email, style: const TextStyle(color: Colors.grey))),
              const SizedBox(height: 32),
              
              const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Default Currency'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Text(user.defaultCurrency, style: const TextStyle(fontWeight: FontWeight.bold)),
                       const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    showCurrencyPicker(
                      context: context,
                      showFlag: true,
                      showCurrencyName: true,
                      showCurrencyCode: true,
                      onSelect: (Currency currency) {
                        ref.read(authControllerProvider.notifier).updateCurrency(currency.code);
                      },
                      theme: CurrencyPickerThemeData(
                        backgroundColor: Theme.of(context).cardColor,
                        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        subtitleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      )
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                style: FilledButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.8)),
                child: const Text('Log Out'),
              ),
            ],
          );
        },
        error: (e, st) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
