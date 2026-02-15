import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_router.dart';
import '../../../core/logging/app_logger.dart';
import '../data/firebase_auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } catch (error, stackTrace) {
      ref.read(appLoggerProvider).e(
            'Failed to sign in.',
            error: error,
            stackTrace: stackTrace,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: Text(_isLoading ? 'Signing in...' : 'Sign In'),
            ),
            TextButton(
              onPressed: () => const SignUpRoute().push(context),
              child: const Text('Create account'),
            ),
            TextButton(
              onPressed: () => const ResetPasswordRoute().push(context),
              child: const Text('Forgot password?'),
            ),
          ],
        ),
      ),
    );
  }
}
