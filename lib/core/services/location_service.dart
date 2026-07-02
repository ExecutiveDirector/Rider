// lib/core/services/location_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/socket_constants.dart';
import 'socket_service.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  final _locationController = StreamController<Position>.broadcast();
  Stream<Position> get onLocationUpdate => _locationController.stream;

  // Request permissions
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[Location] Service disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[Location] Permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[Location] Permission permanently denied');
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  // Get one-time position
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('[Location] Failed to get position: $e');
      return null;
    }
  }

  // Start streaming location updates — battery optimized
  Future<void> startTracking({String? activeOrderId}) async {
    if (_isTracking) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) return;

    _isTracking = true;
    debugPrint('[Location] Started tracking');

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // minimum 15m movement to emit
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) => _onPositionUpdate(position, orderId: activeOrderId),
      onError: (e) => debugPrint('[Location] Stream error: $e'),
    );
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    debugPrint('[Location] Stopped tracking');
  }

  void _onPositionUpdate(Position position, {String? orderId}) {
    // Only send if moved enough (battery optimization)
    if (_lastPosition != null) {
      final distance = _distanceMeters(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance < SocketConstants.minDistanceChangeMeters) return;
    }

    _lastPosition = position;
    _locationController.add(position);

    // Push to socket
    SocketService.instance.sendLocation(
      position.latitude,
      position.longitude,
      orderId: orderId,
    );
  }

  // Haversine distance in meters
  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  void dispose() {
    stopTracking();
    _locationController.close();
  }
}
