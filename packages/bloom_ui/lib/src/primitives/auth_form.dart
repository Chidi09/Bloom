// lib/src/primitives/auth_form.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'button.dart';
import 'card.dart';
import 'checkbox.dart';
import 'form.dart';
import 'input.dart';

class BloomAuthForm extends StatefulWidget {
  final String title;
  final String description;
  final String submitButtonText;
  final Future<void> Function(String email, String password, bool rememberMe) onSubmit;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onToggleAuthMode;
  final String? toggleAuthModeText;

  const BloomAuthForm({
    super.key,
    this.title = 'Welcome back',
    this.description = 'Enter your credentials to access your account.',
    this.submitButtonText = 'Sign in',
    required this.onSubmit,
    this.onForgotPassword,
    this.onToggleAuthMode,
    this.toggleAuthModeText,
  });

  @override
  State<BloomAuthForm> createState() => _BloomAuthFormState();
}

class _BloomAuthFormState extends State<BloomAuthForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.onSubmit(_email.text.trim(), _password.text, _rememberMe);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: BloomCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BloomCardHeader(
                title: Text(widget.title),
                subtitle: Text(widget.description),
              ),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(context.bloomRadius.md),
                    border: Border.all(color: colors.error.withOpacity(0.3)),
                  ),
                  child: Text(_error!, style: TextStyle(color: colors.error, fontSize: 13)),
                ),
              ],
              BloomFormField(
                label: 'Email',
                required: true,
                child: BloomInput(
                  controller: _email,
                  hintText: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              BloomFormField(
                label: 'Password',
                required: true,
                child: BloomInput(
                  controller: _password,
                  hintText: '••••••••',
                  obscureText: true,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BloomCheckbox(
                    checked: _rememberMe,
                    label: const Text('Remember me'),
                    onChanged: (val) => setState(() => _rememberMe = val),
                  ),
                  if (widget.onForgotPassword != null)
                    GestureDetector(
                      onTap: widget.onForgotPassword,
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(color: colors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              BloomButton(
                loading: _isLoading,
                onPressed: _submit,
                child: Text(widget.submitButtonText),
              ),
              if (widget.onToggleAuthMode != null && widget.toggleAuthModeText != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: widget.onToggleAuthMode,
                    child: Text(
                      widget.toggleAuthModeText!,
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
