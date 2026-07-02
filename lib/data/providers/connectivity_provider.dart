// lib/data/providers/connectivity_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/connectivity_service.dart';

/// Emits `true` while online, `false` while offline. Used by
/// [ConnectivityOverlay] to show/hide the no-internet screen app-wide.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ConnectivityService.instance.onStatusChange;
});
