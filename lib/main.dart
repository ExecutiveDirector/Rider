// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/services/api_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/provider_container.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crash and error reporting. Off unless built with
  // --dart-define=SENTRY_DSN=... (set as a GitHub secret for release builds).
  // Never sends personal data, screenshots or performance traces.
  try {
    await SentryFlutter.init((o) {
      // A Sentry DSN only lets clients send events (it is not a secret);
      // a build can still override it with --dart-define=SENTRY_DSN=...
      o.dsn = const String.fromEnvironment('SENTRY_DSN',
          defaultValue:
              'https://140b851a0b9901e6a9674273921fa5e5@o4512316675588096.ingest.de.sentry.io/4512317082566736');
      o.environment = const String.fromEnvironment('APP_ENV', defaultValue: 'production');
      o.sendDefaultPii = false;
      o.attachScreenshot = false;
      o.tracesSampleRate = 0;
    });
  } catch (e) {
    debugPrint('[Sentry] Init failed (non-fatal): $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Firebase: wrapped so a missing/misconfigured google-services.json
  // does NOT crash the app before the splash screen renders.
  // FCM push notifications will simply be disabled until fixed.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[Firebase] Init failed — push notifications disabled: $e');
  }

  // Local storage must succeed — everything depends on it
  await StorageService.instance.init();

  ApiService.instance.init();

  // Permission denial is normal, never crash for it
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('[Notifications] Init failed (non-fatal): $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: appContainer,
      child: const AquaGasRiderApp(),
    ),
  );
}
