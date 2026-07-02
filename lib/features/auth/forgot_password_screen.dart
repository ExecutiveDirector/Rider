// lib/features/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../data/providers/auth_provider.dart';

/// Two-step password reset:
///   Step 1 — enter email, backend sends a reset link to that inbox.
///   Step 2 — paste the token from that link + choose a new password.
///
/// NOTE: the backend emails a reset *link* with a long token
/// (POST /auth/reset-password expects { token, newPassword }), not a
/// short numeric OTP. There's no deep-link handler wired up yet to catch
/// that link automatically, so step 2 asks the rider to copy the token
/// from the end of the link in their email and paste it here. If a true
/// OTP-code flow is wanted later, that needs a backend change (short-code
/// generation + a verify-code endpoint) — this screen matches what the
/// backend actually supports today.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailCtr = TextEditingController();
  final _tokenCtr = TextEditingController();
  final _newPasswordCtr = TextEditingController();
  final _confirmPasswordCtr = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;
  bool _emailSent = false;
  bool _resetDone = false;

  @override
  void dispose() {
    _emailCtr.dispose();
    _tokenCtr.dispose();
    _newPasswordCtr.dispose();
    _confirmPasswordCtr.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_emailCtr.text.trim());
      if (mounted) setState(() => _emailSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitNewPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            token: _tokenCtr.text.trim(),
            newPassword: _newPasswordCtr.text,
          );
      if (mounted) setState(() => _resetDone = true);
    } catch (e) {
      if (mounted) setState(() => _error = dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _resetDone
              ? _buildSuccess()
              : (!_emailSent ? _buildEmailStep() : _buildResetStep()),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forgot your password?',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter the email on your rider account and we'll send you a "
            'reset link.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailCtr,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'rider@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendResetEmail,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Send Reset Link'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mark_email_read_outlined,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'If ${_emailCtr.text.trim()} is registered, a reset '
                    'link was sent. Open it, copy the code from the end of '
                    'the link, and paste it below.',
                    style: const TextStyle(
                        color: AppColors.success, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _tokenCtr,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Reset Code',
              hintText: 'Paste the code from your email',
              prefixIcon: Icon(Icons.key_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter the reset code' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPasswordCtr,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              if (v.length < 8) return 'Must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordCtr,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v != _newPasswordCtr.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _emailSent = false;
                      _error = null;
                    }),
            child: const Text("Didn't get it? Try a different email"),
          ),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitNewPassword,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Reset Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_outline,
            color: AppColors.success, size: 64),
        const SizedBox(height: 20),
        const Text(
          'Password reset!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can now log in with your new password.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Login'),
          ),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}
