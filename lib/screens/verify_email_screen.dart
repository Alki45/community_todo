import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.onEmailVerified});

  static const routeName = '/verify-email';

  final VoidCallback? onEmailVerified;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  bool _isVerified = false;
  bool _isResending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkVerification();
    });
  }

  Future<void> _checkVerification() async {
    final authService = context.read<AuthService>();
    await authService.reloadCurrentUser();
    final isVerified = authService.currentUser?.emailVerified ?? false;
    if (isVerified && !_isVerified) {
      setState(() {
        _isVerified = true;
      });
      widget.onEmailVerified?.call();
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _error = null;
    });

    final authService = context.read<AuthService>();
    try {
      await authService.resendVerificationEmail();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerified) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.teal, size: 64),
              SizedBox(height: 16),
              Text('Email verified! You can close this screen.'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: Colors.teal,
                  size: 72,
                ),
                const SizedBox(height: 16),
                Text(
                  'Check your inbox',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a verification email. Once you confirm it, this screen will close automatically.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Didn’t see it? Check spam or tap below to resend.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isResending ? null : _resendEmail,
                  icon: _isResending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.email_outlined),
                  label: const Text('Resend verification email'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _checkVerification,
                  icon: const Icon(Icons.refresh),
                  label: const Text('I\'ve verified, refresh status'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
