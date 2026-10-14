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

  /// Turn-by-turn steps for the current route.
  final List<RouteStep> steps;

  /// Index into [steps] of the maneuver the rider is approaching.
  final int stepIndex;

  /// Straight-line metres from the rider to the end of the current step.
  final double? metersToNextStep;

  const DirectionsState({
    this.routePoints = const [],
    this.distanceText,
    this.durationText,
    this.isLoading = false,
    this.steps = const [],
    this.stepIndex = 0,
    this.metersToNextStep,
  });

  RouteStep? get currentStep =>
      stepIndex >= 0 && stepIndex < steps.length ? steps[stepIndex] : null;

  DirectionsState copyWith({
    List<LatLng>? routePoints,
    String? distanceText,
    String? durationText,
    bool? isLoading,
    List<RouteStep>? steps,
    int? stepIndex,
    double? metersToNextStep,
  }) {
    return DirectionsState(
      routePoints: routePoints ?? this.routePoints,
      distanceText: distanceText ?? this.distanceText,
      durationText: durationText ?? this.durationText,
      isLoading: isLoading ?? this.isLoading,
      steps: steps ?? this.steps,
      stepIndex: stepIndex ?? this.stepIndex,
      metersToNextStep: metersToNextStep ?? this.metersToNextStep,
    );
  }
}

/// Re-fetches the route to the destination as the rider moves, but throttles
/// calls so we're not hitting the Directions API on every GPS tick (that
/// gets expensive fast on Google's per-request billing).
class DirectionsNotifier extends StateNotifier<DirectionsState> {
  DirectionsNotifier() : super(const DirectionsState());

  LatLng? _lastFetchedFrom;
  LatLng? _lastDestination;
  DateTime? _lastFetchTime;
  static const _minRefetchDistanceMeters = 80;
  static const _minRefetchInterval = Duration(seconds: 25);

  /// A maneuver counts as done once the rider is this close to its end point.
  static const _stepReachedMeters = 30;

  Future<void> updateRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final now = DateTime.now();

    // Switching target (vendor → customer after pickup) must refresh at once
    // rather than waiting out the throttle with a route to the old target.
    final destinationChanged = _lastDestination == null ||
        _distanceMeters(_lastDestination!, destination) > 30;

    if (!destinationChanged &&
        _lastFetchedFrom != null &&
        _lastFetchTime != null) {
      final movedEnough = _distanceMeters(_lastFetchedFrom!, origin) >=
          _minRefetchDistanceMeters;
      final longEnough = now.difference(_lastFetchTime!) >= _minRefetchInterval;
      if (!movedEnough && !longEnough) return;
    }

    _lastFetchedFrom = origin;
    _lastDestination = destination;
    _lastFetchTime = now;
    // Drop the stale route immediately when the target changed.
    state = destinationChanged
        ? const DirectionsState(isLoading: true)
        : state.copyWith(isLoading: true);

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
      steps: result.steps,
      stepIndex: 0,
      metersToNextStep:
          result.steps.isEmpty ? null : _distanceMeters(origin, result.steps[0].end),
    );
  }

  /// Cheap, network-free: advance to the next maneuver as the rider passes
  /// each step's end point. Call on every GPS tick.
  void advanceStep(LatLng position) {
    final steps = state.steps;
    if (steps.isEmpty) return;

    var i = state.stepIndex;
    while (i < steps.length - 1 &&
        _distanceMeters(position, steps[i].end) < _stepReachedMeters) {
      i++;
    }
    state = state.copyWith(
      stepIndex: i,
      metersToNextStep: _distanceMeters(position, steps[i].end),
    );
  }

  void clear() {
    _lastFetchedFrom = null;
    _lastDestination = null;
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
