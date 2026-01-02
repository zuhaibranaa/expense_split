import 'package:flutter/material.dart';
import 'shared/utils/global_keys.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'shared/presentation/app_theme.dart';

class EquisplitApp extends StatelessWidget {
  const EquisplitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Equisplit',
      navigatorKey: navigatorKey,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}
