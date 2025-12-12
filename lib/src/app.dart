import 'package:flutter/material.dart';
import 'shared/utils/global_keys.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'shared/presentation/app_theme.dart';

class SettleUpApp extends StatelessWidget {
  const SettleUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SettleUp Clone',
      navigatorKey: navigatorKey,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}
