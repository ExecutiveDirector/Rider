// lib/features/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/routes.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final repo = AuthRepository();
    final isLoggedIn = await repo.isLoggedIn();

    if (isLoggedIn) {
      // FIX: restore driver profile into authProvider so the rest of the app
      // sees a non-null driver on cold start, not just a valid token.
      try {
        final driver = await repo.restoreSession();
        if (mounted && driver != null) {
          ref.read(authProvider.notifier).setDriver(driver);
        }
      } catch (_) {
        // If profile fetch fails, still proceed — the driver will be
        // populated lazily when screens request it.
      }

      final token = await StorageService.instance.getToken();
      final driverId = await StorageService.instance.getDriverId();

      // FIX: navigate BEFORE socket/push setup, same reasoning as
      // login_screen.dart — an uncaught exception in connect() or
      // registerPushTokenIfAvailable() must never strand a rider with a
      // perfectly valid saved session on the splash screen forever.
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);

      if (token != null && driverId != null) {
        try {
          SocketService.instance.init(token: token, driverId: driverId);
          SocketService.instance.connect();
        } catch (e) {
          debugPrint('[Splash] Socket setup failed (non-fatal): $e');
        }
        try {
          await NotificationService.instance.registerPushTokenIfAvailable();
        } catch (e) {
          debugPrint('[Splash] Push token registration failed (non-fatal): $e');
        }
      }
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🔥', style: TextStyle(fontSize: 44)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'AquaGas Rider',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Delivering gas across Kenya',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
