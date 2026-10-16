// lib/core/services/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../../data/providers/order_provider.dart';
import 'provider_container.dart';
import 'api_service.dart';
import '../constants/api_constants.dart';

const _kNewOrderChannelId = 'new_order_channel';

const _newOrderChannel = AndroidNotificationChannel(
  _kNewOrderChannelId,
  'New Orders',
  description: 'Alerts for incoming delivery orders',
  importance: Importance.max,
  enableVibration: true,
  playSound: true,
);

/// Raises the loud, full-screen "new order" alert. Used by both the foreground
/// handler and the background isolate, so it takes the plugin as an argument.
Future<void> _showOfferAlert(
  FlutterLocalNotificationsPlugin plugin, {
  required String title,
  required String body,
  String? orderId,
}) async {
  await plugin.show(
    // Stable id per order so a re-offer replaces rather than stacks.
    orderId != null
        ? (int.tryParse(orderId) ?? orderId.hashCode) & 0x7fffffff
        : DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _kNewOrderChannelId,
        'New Orders',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        timeoutAfter: 45000, // offers expire; don't leave a stale alert
        ticker: 'New delivery order',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    ),
    payload: orderId,
  );
}

/// Runs in its own isolate when a data-only push arrives while the app is in the
/// background or killed (the backend sends job offers this way — see
/// pushNotificationService.buildMessage). Without this the offer only
/// appeared after the rider opened the app.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  debugPrint('[FCM] Background message: ${message.messageId}');
  final data = message.data;
  // A message that carries a `notification` block is shown by the system.
  if (message.notification != null || data['type'] != 'new_order') return;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ));
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_newOrderChannel);
  await _showOfferAlert(
    plugin,
    title: data['title'] ?? 'New Delivery Order!',
    body: data['body'] ?? 'You have a new delivery request',
    orderId: data['orderId'],
  );
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Broadcast stream so the NotificationsScreen can listen to foreground FCM
  final _foregroundController =
      StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get onForegroundMessage =>
      _foregroundController.stream;

  /// Offer the rider tapped while the app was closed. The UI isn't ready (and
  /// the rider may not be signed in yet) at launch, so HomeScreen consumes it.
  String? _pendingOfferId;
  String? takePendingOffer() {
    final id = _pendingOfferId;
    _pendingOfferId = null;
    return id;
  }

  static const _newOrderChannelId = _kNewOrderChannelId;
  static const _generalChannelId = 'general_channel';

  Future<void> init() async {
    // FCM permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true, // important for delivery apps
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Local notifications init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create channels (Android)
    // FIX: this used to reference RawResourceAndroidNotificationSound
    // ('order_alert'), but android/app/src/main/res/raw/order_alert.* was
    // never actually added to the project — there's no res/raw folder at
    // all. createNotificationChannel() threw on that missing resource,
    // and because this whole init() is wrapped in a try/catch back in
    // main.dart, the failure was swallowed silently — but it also meant
    // NOTHING after this point ran: no FCM foreground listener, no
    // onMessageOpenedApp listener, no token registration. That's very
    // likely why notifications weren't working at all, not just the sound.
    // Using the default system sound (playSound: true, no `sound:`) is
    // guaranteed to exist, so this can't take down the rest of init.
    // Swap in a custom raw resource later if you want a distinct tone —
    // just make sure the file actually exists under res/raw first.
    if (Platform.isAndroid) {
      try {
        final androidImpl = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await androidImpl?.createNotificationChannel(_newOrderChannel);
        // Android 14+: full-screen alerts need an explicit grant.
        await androidImpl?.requestFullScreenIntentPermission();

        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            _generalChannelId,
            'General',
            description: 'General app notifications',
            importance: Importance.defaultImportance,
            playSound: true,
          ),
        );
      } catch (e) {
        debugPrint('[Notifications] Channel creation failed (non-fatal): $e');
      }
    }

    // Listen to foreground FCM
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // FIX: this token was previously only ever logged, never sent to the
    // backend — so device_tokens never had a row for this rider, and
    // sendPushNotificationToRider() on the backend always found zero
    // tokens no matter what. Register it now, and again whenever it
    // rotates (FCM tokens can change).
    // App launched by tapping an offer while it was terminated.
    try {
      final initial = await _fcm.getInitialMessage();
      if (initial?.data['type'] == 'new_order') {
        _pendingOfferId = initial!.data['orderId'];
      }
      final launch = await _localNotifications.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.isNotEmpty) {
        _pendingOfferId = payload;
      }
    } catch (e) {
      debugPrint('[Notifications] Launch details failed (non-fatal): $e');
    }

    final token = await _fcm.getToken();
    debugPrint('[Notifications] FCM Token: $token');
    if (token != null) await _registerTokenWithBackend(token);
    _fcm.onTokenRefresh.listen(_registerTokenWithBackend);
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await ApiService.instance.post(
        ApiConstants.pushTokenRegister,
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
      debugPrint('[Notifications] Push token registered with backend');
    } catch (e) {
      // Non-fatal — rider just won't get push fallback until next
      // successful registration (app relaunch, token refresh, etc.)
      debugPrint('[Notifications] Failed to register push token: $e');
    }
  }

  /// Call after login / session-restore, once an auth token exists.
  /// init() itself may run before the rider is logged in (app cold start,
  /// splash screen), so registration is retried here once we know a
  /// request can actually succeed.
  Future<void> registerPushTokenIfAvailable() async {
    final token = await _fcm.getToken();
    if (token != null) await _registerTokenWithBackend(token);
  }

  /// Call on logout. Matches DELETE /riders/push-token/unregister
  /// (riderController.unregisterRiderPushToken). Best-effort — if this
  /// fails the token just goes stale on the backend, which is harmless.
  Future<void> unregisterToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await ApiService.instance.delete(
        ApiConstants.pushTokenUnregister,
        data: {'token': token},
      );
    } catch (e) {
      debugPrint('[Notifications] Failed to unregister push token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? 'general';

    // Emit to the in-app stream so NotificationsScreen can pick it up
    _foregroundController.add({
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? data['title'] ?? '',
      'body': message.notification?.body ?? data['body'] ?? '',
      'type': type,
    });

    if (type == 'new_order') {
      showNewOrderNotification(
        title: message.notification?.title ?? data['title'] ?? 'New Order!',
        body: message.notification?.body ??
            data['body'] ??
            'You have a new delivery request',
        orderId: data['orderId'],
      );
      final orderId = data['orderId'];
      if (orderId != null) {
        appContainer
            .read(orderProvider.notifier)
            .showIncomingOrderById(orderId);
      }
    } else {
      showGeneralNotification(
        title: message.notification?.title ?? 'AquaGas',
        body: message.notification?.body ?? '',
      );
    }
  }

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[Notifications] Opened: ${message.data}');
    final orderId = message.data['orderId'];
    if (message.data['type'] == 'new_order' && orderId != null) {
      appContainer.read(orderProvider.notifier).showIncomingOrderById(orderId);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Local "new order" notifications are shown with payload = orderId
    // (see showNewOrderNotification below).
    debugPrint('[Notifications] Tapped: ${response.payload}');
    final orderId = response.payload;
    if (orderId != null && orderId.isNotEmpty) {
      appContainer.read(orderProvider.notifier).showIncomingOrderById(orderId);
    }
  }

  Future<void> showNewOrderNotification({
    required String title,
    required String body,
    String? orderId,
  }) =>
      _showOfferAlert(_localNotifications,
          title: title, body: body, orderId: orderId);

  Future<void> showGeneralNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _generalChannelId,
          'General',
          importance: Importance.defaultImportance,
        ),
      ),
      payload: payload,
    );
  }

  Future<String?> getFcmToken() => _fcm.getToken();
}
