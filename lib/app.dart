// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/routes.dart';
import 'core/config/theme.dart';
import 'core/services/api_service.dart';
import 'core/widgets/connectivity_overlay.dart';
import 'data/providers/theme_provider.dart';
import 'data/providers/order_provider.dart';
import 'features/orders/widgets/incoming_order_sheet.dart';

class AquaGasRiderApp extends ConsumerWidget {
  const AquaGasRiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // FIX: this used to live inside HomeScreen.build(), so it only fired
    // while HomeScreen happened to be mounted. Living here means an
    // assigned order pops the accept/reject sheet no matter which screen
    // the rider is currently on — Active Orders, Order Details, Profile, etc.
    ref.listen(orderProvider.select((s) => s.incomingOrder), (prev, next) {
      if (next != null && prev == null) {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return;
        showModalBottomSheet(
          context: ctx,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (_) => IncomingOrderSheet(order: next),
        );
      }
    });

    return MaterialApp(
      title: 'AquaGas Rider',
      debugShowCheckedModeBanner: false,
      // FIX: wire the global navigator key so the auth interceptor can
      // push to /login after a failed token refresh, from outside the tree.
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.generateRoute,
      builder: (context, child) =>
          ConnectivityOverlay(child: child ?? const SizedBox()),
    );
  }
}
