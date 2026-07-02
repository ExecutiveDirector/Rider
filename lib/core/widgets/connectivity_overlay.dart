// lib/core/widgets/connectivity_overlay.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../services/socket_service.dart';
import '../../data/providers/connectivity_provider.dart';

class ConnectivityOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivityOverlay({super.key, required this.child});

  @override
  ConsumerState<ConnectivityOverlay> createState() =>
      _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends ConsumerState<ConnectivityOverlay> {
  SocketStatus _socketStatus = SocketStatus.disconnected;
  StreamSubscription? _socketSub;
  bool _showSocketBanner = false;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _socketSub = SocketService.instance.onStatusChange.listen((status) {
      if (!mounted) return;
      setState(() => _socketStatus = status);

      if (status == SocketStatus.reconnected) {
        // Show a brief "reconnected" confirmation then auto-hide
        setState(() => _showSocketBanner = true);
        _bannerTimer?.cancel();
        _bannerTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSocketBanner = false);
        });
      } else if (status == SocketStatus.disconnected ||
          status == SocketStatus.reconnecting) {
        setState(() => _showSocketBanner = true);
        _bannerTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final isOffline = isOnlineAsync.maybeWhen(
      data: (online) => !online,
      orElse: () => false,
    );

    return Stack(
      children: [
        widget.child,

        // Full-screen no-internet overlay
        if (isOffline)
          Positioned.fill(
            child: _NoInternetView(
              onRetry: () => ref.invalidate(isOnlineProvider),
            ),
          ),

        // Non-blocking socket status banner (shows only when online but socket dropped)
        if (!isOffline && _showSocketBanner)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _SocketStatusBanner(
              status: _socketStatus,
              onDismiss: () => setState(() => _showSocketBanner = false),
            ),
          ),
      ],
    );
  }
}

class _SocketStatusBanner extends StatelessWidget {
  final SocketStatus status;
  final VoidCallback onDismiss;
  const _SocketStatusBanner(
      {required this.status, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isReconnected = status == SocketStatus.reconnected;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isReconnected
              ? AppColors.success
              : const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isReconnected
                  ? Icons.wifi_rounded
                  : Icons.wifi_off_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isReconnected
                    ? 'Connection restored'
                    : status == SocketStatus.reconnecting
                        ? 'Reconnecting to server…'
                        : 'Connection lost — orders may be delayed',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoInternetView extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoInternetView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withOpacity(0.97),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 72,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Internet Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your mobile data or Wi-Fi and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(160, 48),
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
