import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_picker/currency_picker.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _currency = 'USD';

  int _step =
      0; // 0: Email, 1: Password (Login) or Password (Register), 2: Profile (Register)
  bool _isNewUser = false;

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final exists = await ref
          .read(authControllerProvider.notifier)
          .checkEmail(email);
      setState(() {
        _isNewUser = !exists;
        _step = 1;
      });
    } catch (e) {
      // Error handled by global handler, but we stop loading
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);
    } catch (e) {
      // Global error handler shows popup
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleRegisterNext() {
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            _emailController.text.trim(),
            _passwordController.text,
            _nameController.text.trim().isEmpty
                ? 'User'
                : _nameController.text.trim(),
            _currency,
          );
    } catch (e) {
      // Global handler
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Remove authState usage for loading, rely on local state
    final isLoading = _isLoading;

    // Error Listener
    ref.listen<AsyncValue>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auth failed: ${next.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.security, size: 64, color: Color(0xFF00E5FF)),
              const SizedBox(height: 32),

              if (_step == 0) ...[
                Text(
                  'Welcome to SettleUp',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email to continue',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  onSubmitted: (_) => _handleEmailSubmit(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isLoading ? null : _handleEmailSubmit,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Continue'),
                ),

                const SizedBox(height: 16),
                // Demo button removed as requested
              ],

              if (_step == 1) ...[
                Text(
                  _isNewUser ? 'Create Password' : 'Welcome Back',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _emailController.text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  autofocus: true,
                  onSubmitted: (_) =>
                      _isNewUser ? _handleRegisterNext() : _handleLogin(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : (_isNewUser ? _handleRegisterNext : _handleLogin),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isNewUser ? 'Next' : 'Login'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _step = 0;
                    _passwordController.clear();
                  }),
                  child: const Text('Back'),
                ),
              ],

              if (_step == 2) ...[
                Text(
                  'Complete Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Default Currency'),
                  subtitle: Text(_currency),
                  trailing: const Icon(Icons.arrow_drop_down),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  onTap: () {
                    showCurrencyPicker(
                      context: context,
                      showFlag: true,
                      showCurrencyName: true,
                      showCurrencyCode: true,
                      onSelect: (Currency currency) {
                        setState(() => _currency = currency.code);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isLoading ? null : _handleRegister,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
