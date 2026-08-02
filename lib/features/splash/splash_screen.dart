// lib/features/splash/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_logo_mark.dart';
import '../../core/config/routes.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/notification_watcher_service.dart';
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
        unawaited(NotificationWatcherService.instance.start());
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.deepGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft decorative glow orbs — pure UI, no logic.
            Positioned(
              top: -70,
              right: -60,
              child: _GlowOrb(color: AppColors.accentMint, size: 220),
            ),
            Positioned(
              bottom: -90,
              left: -70,
              child: _GlowOrb(color: AppColors.primary, size: 260),
            ),
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogoMark(size: 96),
                      const SizedBox(height: 24),
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
                        'Delivering gas & water across Kenya',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 40),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(
                              Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft, blurred-looking circular gradient — purely decorative background
/// texture for the splash hero. No BackdropFilter needed: a radial gradient
/// fading to transparent gives the same "glow" read at a fraction of the
/// render cost.
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.35), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}
