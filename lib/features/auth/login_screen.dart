// lib/features/auth/login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/routes.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/notification_watcher_service.dart';
import '../../data/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierCtr = TextEditingController();
  final _passwordCtr   = TextEditingController();
  final _formKey       = GlobalKey<FormState>();
  bool _obscurePassword = true;

  // Tracks what the user is currently typing so the UI adapts in real time
  _InputType _inputType = _InputType.unknown;

  @override
  void initState() {
    super.initState();
    _identifierCtr.addListener(_onIdentifierChanged);
  }

  void _onIdentifierChanged() {
    final detected = _detectType(_identifierCtr.text.trim());
    if (detected != _inputType) setState(() => _inputType = detected);
  }

  _InputType _detectType(String value) {
    if (value.isEmpty) return _InputType.unknown;
    // Email: must contain @ followed by at least one dot after it
    if (value.contains('@') && value.contains('.')) return _InputType.email;
    // Phone: starts with 0 / +254 / 254, or is all digits ≥ 9 chars
    final digitsOnly = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (digitsOnly.startsWith('0') ||
        digitsOnly.startsWith('+254') ||
        digitsOnly.startsWith('254') ||
        RegExp(r'^\d{9,}$').hasMatch(digitsOnly)) {
      return _InputType.phone;
    }
    return _InputType.unknown;
  }

  @override
  void dispose() {
    _identifierCtr.dispose();
    _passwordCtr.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).login(
          _identifierCtr.text.trim(),
          _passwordCtr.text,
        );

    final state = ref.read(authProvider);
    if (!state.isAuthenticated || !mounted) return;

    // FIX: this used to run socket connect + push-token registration
    // BEFORE navigating. If either one threw (bad network, plugin
    // hiccup, whatever), the exception was uncaught and silently killed
    // the rest of _login() — so the rider was fully logged in (token
    // already saved) but never got navigated to Home. Navigate first;
    // treat socket/push setup as best-effort background work that can
    // never block getting the rider into the app after a successful login.
    Navigator.pushReplacementNamed(context, AppRoutes.home);

    try {
      final token = await StorageService.instance.getToken();
      if (token != null) {
        SocketService.instance.init(token: token, driverId: state.driver!.id);
        SocketService.instance.connect();
      }
    } catch (e) {
      debugPrint('[Login] Socket setup failed (non-fatal): $e');
    }

    try {
      await NotificationService.instance.registerPushTokenIfAvailable();
    } catch (e) {
      debugPrint('[Login] Push token registration failed (non-fatal): $e');
    }

    // Poll-based fallback for notifications that don't arrive over FCM
    // (see NotificationWatcherService for why this matters — it's the
    // same gap the vendor app already covers).
    unawaited(NotificationWatcherService.instance.start());
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validateIdentifier(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Enter your phone number or email';
    }
    final type = _detectType(v.trim());
    if (type == _InputType.email) {
      // Basic RFC-ish check
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
        return 'Enter a valid email address';
      }
    } else {
      // Treat anything else as a phone — strip non-digits and check length
      final digits = v.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length < 9) return 'Enter a valid phone number';
    }
    return null;
  }

  // ── Dynamic field properties ──────────────────────────────────────────────

  TextInputType get _keyboardType {
    switch (_inputType) {
      case _InputType.email:
        return TextInputType.emailAddress;
      default:
        // FIX: was TextInputType.phone by default, which on most devices
        // shows a numeric dial pad with NO letter keys at all — so a rider
        // typing an email address couldn't even type the first letter to
        // trigger detection. TextInputType.text gives a full keyboard
        // (letters + a number row) that works for typing either.
        return TextInputType.text;
    }
  }

  String get _fieldLabel {
    switch (_inputType) {
      case _InputType.email:
        return 'Email Address';
      case _InputType.phone:
        return 'Phone Number';
      default:
        return 'Phone Number or Email';
    }
  }

  IconData get _fieldIcon {
    switch (_inputType) {
      case _InputType.email:
        return Icons.email_outlined;
      case _InputType.phone:
        return Icons.phone_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String? get _fieldHint {
    switch (_inputType) {
      case _InputType.email:
        return 'rider@example.com';
      case _InputType.phone:
        return '0712 345 678';
      default:
        return '0712 345 678  or  email@example.com';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // Logo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('🔥', style: TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'Welcome back,\nRider 👋',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Login to start accepting deliveries',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 40),

                // ── Smart identifier field ─────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: TextFormField(
                    key: ValueKey(_inputType), // rebuilds decoration smoothly
                    controller: _identifierCtr,
                    keyboardType: _keyboardType,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: _fieldLabel,
                      hintText: _fieldHint,
                      hintStyle: const TextStyle(
                          fontSize: 12, color: AppColors.textHint),
                      prefixIcon: Icon(_fieldIcon),
                      // Tiny chip that shows the detected type
                      suffixIcon: _inputType != _InputType.unknown
                          ? Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Chip(
                                label: Text(
                                  _inputType == _InputType.email
                                      ? 'Email'
                                      : 'Phone',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.08),
                                side: BorderSide(
                                    color: AppColors.primary.withOpacity(0.2)),
                                labelStyle: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            )
                          : null,
                    ),
                    validator: _validateIdentifier,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Password ───────────────────────────────────────────────
                TextFormField(
                  controller: _passwordCtr,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) =>
                      authState.isLoading ? null : _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 6) return 'Password too short';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.forgotPassword),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Error banner ───────────────────────────────────────────
                if (authState.error != null)
                  _ErrorBanner(message: authState.error!),

                const SizedBox(height: 24),

                // ── Login button ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _login,
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Login'),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _InputType { unknown, phone, email }

// ── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  bool get _isPending =>
      message.toLowerCase().contains('pending') ||
      message.toLowerCase().contains('approval') ||
      message.toLowerCase().contains('supervisor');

  @override
  Widget build(BuildContext context) {
    final color = _isPending ? const Color(0xFFF59E0B) : AppColors.error;
    final icon =
        _isPending ? Icons.hourglass_top_rounded : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPending ? 'Account Pending Approval' : 'Login Failed',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style:
                      TextStyle(color: color, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
