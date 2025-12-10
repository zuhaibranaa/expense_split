import 'features/groups/presentation/groups_list_screen.dart';import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'shared/presentation/app_theme.dart';

class SettleUpApp extends StatelessWidget {
  const SettleUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SettleUp Clone',
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}
