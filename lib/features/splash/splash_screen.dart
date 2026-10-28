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
    with TickerProviderStateMixin {
  // One-shot entrance: logo pops in, then the text and loader stagger up.
  late final AnimationController _intro;
  // Gentle idle motion once everything is on screen.
  late final AnimationController _idle;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _badge;
  late final Animation<double> _tagline;
  late final Animation<double> _loader;

  Animation<double> _interval(double a, double b, [Curve c = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(a, b, curve: c));

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 0.55, end: 1.0)
        .animate(_interval(0.0, 0.5, Curves.easeOutBack));
    _logoFade = _interval(0.0, 0.3, Curves.easeOut);
    _badge = _interval(0.35, 0.65);
    _tagline = _interval(0.5, 0.8);
    _loader = _interval(0.7, 1.0);
    _intro.forward();
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

      // Read after the profile call: it may have refreshed the access token.
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
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  /// Fades a child in while sliding it up a little.
  Widget _rise(Animation<double> t, Widget child) => Opacity(
        opacity: t.value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t.value)), child: child),
      );

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
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _idle]),
                builder: (context, _) {
                  final float = Curves.easeInOut.transform(_idle.value) * 6 - 3;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo card with a soft pulsing halo.
                      Opacity(
                        opacity: _logoFade.value,
                        child: Transform.translate(
                          offset: Offset(0, float),
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentMint
                                        .withOpacity(0.25 + 0.2 * _idle.value),
                                    blurRadius: 30 + 18 * _idle.value,
                                    spreadRadius: 2 + 4 * _idle.value,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 200,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const AppLogoMark(size: 72),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      _rise(
                        _badge,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.35)),
                          ),
                          child: const Text(
                            'RIDER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _rise(
                        _tagline,
                        Text(
                          'Delivering gas & water across Kenya',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 44),
                      Opacity(
                        opacity: _loader.value,
                        child: SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
