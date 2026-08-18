import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom_todo_ui/ui.dart';
import '../../app/boot.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameCtrl = TextEditingController(text: 'Alex Rivers');
  final _emailCtrl = TextEditingController(text: 'alex@bloomtodo.dev');
  final _passCtrl = TextEditingController(text: 'password123');
  bool _loading = false;
  String? _error;

  Future<void> _handleSignup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await BloomBoot.authController.signup(_emailCtrl.text, _passCtrl.text, _nameCtrl.text);
      if (mounted) context.go('/today');
    } catch (e) {
      setState(() => _error = 'Could not create account');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: BloomCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.rocket_launch, size: 48, color: TodoColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Create an account',
                        textAlign: TextAlign.center,
                        style: TodoTypography.h2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start organizing your work with Bloom Todo',
                        textAlign: TextAlign.center,
                        style: TodoTypography.body.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        BloomBadge(
                          variant: BloomBadgeVariant.destructive,
                          child: Text(_error!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email Address'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                      ),
                      const SizedBox(height: 24),
                      BloomButton(
                        size: BloomButtonSize.lg,
                        loading: _loading,
                        onPressed: _handleSignup,
                        child: const Text('Sign Up'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Already have an account? Log In'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
