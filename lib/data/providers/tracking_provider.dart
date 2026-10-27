// lib/data/providers/tracking_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/location_service.dart';

class TrackingState {
  final LatLng? currentPosition;
  final double? heading;
  final double? speedMps;
  final bool isTracking;
  final String? activeOrderId;

  const TrackingState({
    this.currentPosition,
    this.heading,
    this.speedMps,
    this.isTracking = false,
    this.activeOrderId,
  });
}

/// UI-side view of [LocationService].
///
/// The service itself keeps running for as long as the rider is online (it is
/// started/stopped by the online toggle). This notifier only attaches a map
/// screen to it: [startTracking] tags the stream with the order being
/// delivered and subscribes for display; [stopTracking] detaches again
/// WITHOUT stopping the service, so leaving the map no longer takes the rider
/// off dispatch's radar.
class TrackingNotifier extends StateNotifier<TrackingState> {
  StreamSubscription<Position>? _locationSub;

  TrackingNotifier() : super(const TrackingState());

  Future<void> startTracking(String orderId) async {
    // Re-seed from the last known fix so the map doesn't open on a blank
    // default position while waiting for the next GPS event.
    final last = LocationService.instance.lastPosition;
    state = TrackingState(
      currentPosition:
          last == null ? null : LatLng(last.latitude, last.longitude),
      heading: last?.heading,
      speedMps: last?.speed,
      isTracking: true,
      activeOrderId: orderId,
    );

    // Starts the service if it isn't running yet (e.g. permissions were
    // granted late); otherwise only updates the order tag.
    await LocationService.instance.startTracking(activeOrderId: orderId);

    // Subscribe exactly once, however many times a screen re-attaches.
    await _locationSub?.cancel();
    _locationSub =
        LocationService.instance.onLocationUpdate.listen((position) {
      state = TrackingState(
        currentPosition: LatLng(position.latitude, position.longitude),
        heading: position.heading,
        speedMps: position.speed,
        isTracking: true,
        activeOrderId: state.activeOrderId,
      );
    });
  }

  /// Detach the map from the location stream. Does not stop the service.
  void stopTracking() {
    _locationSub?.cancel();
    _locationSub = null;
    LocationService.instance.setActiveOrder(null);
    state = TrackingState(currentPosition: state.currentPosition);
  }

  Future<void> fetchCurrentLocation() async {
    final position = await LocationService.instance.getCurrentPosition();
    if (position != null) {
      state = TrackingState(
        currentPosition: LatLng(position.latitude, position.longitude),
        heading: position.heading,
        speedMps: position.speed,
        isTracking: state.isTracking,
        activeOrderId: state.activeOrderId,
      );
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }
}

final trackingProvider = StateNotifierProvider<TrackingNotifier, TrackingState>(
  (_) => TrackingNotifier(),
);
