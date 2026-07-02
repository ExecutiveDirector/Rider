// lib/features/profile/screens/change_password_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();

  final _newPasswordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  bool _currentObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;

  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO:
      // Call API here
      //
      // await RiderRepository.changePassword(
      //   currentPassword:
      //      _currentPasswordController.text.trim(),
      //   newPassword:
      //      _newPasswordController.text.trim(),
      // );

      await Future.delayed(
        const Duration(seconds: 2),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(
    String label,
    bool obscure,
    VoidCallback toggle,
  ) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: toggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      appBar: AppBar(
        title: const Text('Change Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_reset,
                    size: 70,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Update Your Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a strong password to keep your account secure.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _currentObscure,
                    decoration: _inputDecoration(
                      'Current Password',
                      _currentObscure,
                      () {
                        setState(() {
                          _currentObscure = !_currentObscure;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Current password required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _newObscure,
                    decoration: _inputDecoration(
                      'New Password',
                      _newObscure,
                      () {
                        setState(() {
                          _newObscure = !_newObscure;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'New password required';
                      }

                      if (value.length < 8) {
                        return 'Minimum 8 characters';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _confirmObscure,
                    decoration: _inputDecoration(
                      'Confirm Password',
                      _confirmObscure,
                      () {
                        setState(() {
                          _confirmObscure = !_confirmObscure;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Update Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Use a strong password with letters, numbers and symbols. Avoid reusing passwords from other apps.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
