// lib/core/services/provider_container.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global container so singleton services that live outside the widget
/// tree (FCM background/tap handlers, socket service) can read/update
/// Riverpod state directly — e.g. pushing a pending order into
/// [orderProvider] from a notification tap.
final ProviderContainer appContainer = ProviderContainer();
