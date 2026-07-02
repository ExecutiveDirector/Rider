// lib/features/profile/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/repositories/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtr = TextEditingController();
  final _lastNameCtr = TextEditingController();
  final _emailCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _nationalIdCtr = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  final _repo = ProfileRepository();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _repo.getProfile();
      if (mounted) {
        // Split the combined name back into first/last
        final parts = profile.name.trim().split(RegExp(r'\s+'));
        _firstNameCtr.text = parts.isNotEmpty ? parts.first : '';
        _lastNameCtr.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        _emailCtr.text = profile.email;
        _phoneCtr.text = profile.phone;
        _nationalIdCtr.text = profile.nationalId ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dioErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final fullName =
          '${_firstNameCtr.text.trim()} ${_lastNameCtr.text.trim()}'.trim();

      await _repo.updateProfile(
        name: fullName,
        phone: _phoneCtr.text.trim(),
        nationalId: _nationalIdCtr.text.trim().isEmpty
            ? null
            : _nationalIdCtr.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dioErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _firstNameCtr.dispose();
    _lastNameCtr.dispose();
    _emailCtr.dispose();
    _phoneCtr.dispose();
    _nationalIdCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── First Name ──────────────────────────────────
                    TextFormField(
                      controller: _firstNameCtr,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'First name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Last Name ───────────────────────────────────
                    TextFormField(
                      controller: _lastNameCtr,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Last name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Email (read-only — lives in auth_accounts) ──
                    TextFormField(
                      controller: _emailCtr,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        helperText: 'Contact support to change your email',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Phone ───────────────────────────────────────
                    TextFormField(
                      controller: _phoneCtr,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Phone is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ── National ID ─────────────────────────────────
                    TextFormField(
                      controller: _nationalIdCtr,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'National ID (optional)',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Save button ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
