// lib/features/notifications/notifications_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/api_service.dart';

// ── Simple model for a received notification ─────────────────────────────────

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'new_order' | 'general' | 'payment' | 'system'
  final DateTime receivedAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
    this.isRead = false,
  });
}

// ── Provider ──────────────────────────────────────────────────────────────────

class _NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  StreamSubscription? _sub;

  _NotificationsNotifier() : super([]) {
    _listenToFCM();
    _fetchFromApi();
  }

  void _listenToFCM() {
    // Wire into NotificationService's foreground stream
    // New FCM messages are prepended so the latest is always at top
    _sub = NotificationService.instance.onForegroundMessage.listen((msg) {
      final n = AppNotification(
        id: msg['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: msg['title'] ?? 'AquaGas',
        body: msg['body'] ?? '',
        type: msg['type'] ?? 'general',
        receivedAt: DateTime.now(),
      );
      state = [n, ...state];
    });
  }

  Future<void> _fetchFromApi() async {
    try {
      final response =
          await ApiService.instance.get('/riders/notifications');
      final list = response.data['data'] as List? ?? [];
      final fetched = list.map((j) {
        return AppNotification(
          // FIX: backend returns snake_case (notification_id,
          // notification_type, created_at) — this only ever checked the
          // camelCase names, so every notification fetched from the API
          // (as opposed to ones that arrived live over FCM) had a blank
          // id, always showed as type 'general', and always showed "just
          // now" instead of its real timestamp.
          id: (j['notification_id'] ?? j['id'])?.toString() ?? '',
          title: j['title'] ?? '',
          body: j['message'] ?? j['body'] ?? '',
          type: j['notification_type'] ?? j['type'] ?? 'general',
          receivedAt: DateTime.tryParse(
                  j['created_at'] ?? j['createdAt'] ?? '') ??
              DateTime.now(),
          isRead: j['is_read'] == 1 || j['is_read'] == true || j['isRead'] == true,
        );
      }).toList();
      // Merge: API results go after any locally-received FCM ones
      state = [...state, ...fetched];
    } catch (_) {
      // Silently fail — local FCM notifications are still shown
    }
  }

  void markAllRead() {
    state = state.map((n) => n..isRead = true).toList();
    // Best-effort API call
    ApiService.instance
        .post('/riders/notifications/read-all')
        .catchError((_) {});
  }

  void markRead(String id) {
    state = state.map((n) {
      if (n.id == id) n.isRead = true;
      return n;
    }).toList();
    ApiService.instance
        .post('/riders/notifications/$id/read')
        .catchError((_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final _notificationsProvider = StateNotifierProvider<_NotificationsNotifier,
    List<AppNotification>>((_) => _NotificationsNotifier());

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(_notificationsProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(_notificationsProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _EmptyState()
          : RefreshIndicator(
              onRefresh: () async => ref
                  .read(_notificationsProvider.notifier)
                  ._fetchFromApi(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) {
                  final n = notifications[i];
                  return _NotificationTile(
                    notification: n,
                    onTap: () => ref
                        .read(_notificationsProvider.notifier)
                        .markRead(n.id),
                  );
                },
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile(
      {required this.notification, required this.onTap});

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_order':
        return Icons.local_shipping_outlined;
      case 'payment':
        return Icons.account_balance_wallet_outlined;
      case 'system':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'new_order':
        return AppColors.primary;
      case 'payment':
        return AppColors.success;
      case 'system':
        return AppColors.textSecondary;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(notification.type);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead
            ? null
            : AppColors.primary.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(notification.type),
                  color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification.receivedAt),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM, h:mm a').format(dt);
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'New orders and updates will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
