// lib/data/providers/directions_provider.dart
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/directions_service.dart';

class DirectionsState {
  final List<LatLng> routePoints;
  final String? distanceText;
  final String? durationText;
  final bool isLoading;

  const DirectionsState({
    this.routePoints = const [],
    this.distanceText,
    this.durationText,
    this.isLoading = false,
  });

  DirectionsState copyWith({
    List<LatLng>? routePoints,
    String? distanceText,
    String? durationText,
    bool? isLoading,
  }) {
    return DirectionsState(
      routePoints: routePoints ?? this.routePoints,
      distanceText: distanceText ?? this.distanceText,
      durationText: durationText ?? this.durationText,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Re-fetches the route to the destination as the rider moves, but throttles
/// calls so we're not hitting the Directions API on every GPS tick (that
/// gets expensive fast on Google's per-request billing).
class DirectionsNotifier extends StateNotifier<DirectionsState> {
  DirectionsNotifier() : super(const DirectionsState());

  LatLng? _lastFetchedFrom;
  DateTime? _lastFetchTime;
  static const _minRefetchDistanceMeters = 80;
  static const _minRefetchInterval = Duration(seconds: 25);

  Future<void> updateRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final now = DateTime.now();
    if (_lastFetchedFrom != null && _lastFetchTime != null) {
      final movedEnough = _distanceMeters(_lastFetchedFrom!, origin) >=
          _minRefetchDistanceMeters;
      final longEnough = now.difference(_lastFetchTime!) >= _minRefetchInterval;
      if (!movedEnough && !longEnough) return;
    }

    _lastFetchedFrom = origin;
    _lastFetchTime = now;
    state = state.copyWith(isLoading: true);

    final result = await DirectionsService.instance.getDirections(
      origin: origin,
      destination: destination,
    );

    if (result == null) {
      // Fail soft — keep whatever route we last had, just stop the spinner.
      state = state.copyWith(isLoading: false);
      return;
    }

    state = DirectionsState(
      routePoints: result.polylinePoints,
      distanceText: result.distanceText,
      durationText: result.durationText,
      isLoading: false,
    );
  }

  void clear() {
    _lastFetchedFrom = null;
    _lastFetchTime = null;
    state = const DirectionsState();
  }

  // Haversine — same approach as LocationService, kept local to avoid a
  // cross-import just for one distance check.
  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _toRad(double deg) => deg * math.pi / 180;
}

final directionsProvider =
    StateNotifierProvider<DirectionsNotifier, DirectionsState>(
  (_) => DirectionsNotifier(),
);
