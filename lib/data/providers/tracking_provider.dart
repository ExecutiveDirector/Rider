// lib/data/providers/tracking_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/location_service.dart';

class TrackingState {
  final LatLng? currentPosition;
  final List<LatLng> routePoints;
  final bool isTracking;
  final String? activeOrderId;

  const TrackingState({
    this.currentPosition,
    this.routePoints = const [],
    this.isTracking = false,
    this.activeOrderId,
  });

  TrackingState copyWith({
    LatLng? currentPosition,
    List<LatLng>? routePoints,
    bool? isTracking,
    String? activeOrderId,
  }) {
    return TrackingState(
      currentPosition: currentPosition ?? this.currentPosition,
      routePoints: routePoints ?? this.routePoints,
      isTracking: isTracking ?? this.isTracking,
      activeOrderId: activeOrderId ?? this.activeOrderId,
    );
  }
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  StreamSubscription<Position>? _locationSub;

  TrackingNotifier() : super(const TrackingState());

  Future<void> startTracking(String orderId) async {
    state = state.copyWith(isTracking: true, activeOrderId: orderId);
    await LocationService.instance.startTracking(activeOrderId: orderId);

    _locationSub = LocationService.instance.onLocationUpdate.listen((position) {
      final latLng = LatLng(position.latitude, position.longitude);
      final updatedRoute = [...state.routePoints, latLng];
      state = state.copyWith(
        currentPosition: latLng,
        routePoints: updatedRoute,
      );
    });
  }

  void stopTracking() {
    LocationService.instance.stopTracking();
    _locationSub?.cancel();
    state = const TrackingState();
  }

  Future<void> fetchCurrentLocation() async {
    final position = await LocationService.instance.getCurrentPosition();
    if (position != null) {
      state = state.copyWith(
        currentPosition: LatLng(position.latitude, position.longitude),
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
