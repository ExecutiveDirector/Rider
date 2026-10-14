// lib/core/services/location_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/api_constants.dart';
import '../constants/socket_constants.dart';
import 'api_service.dart';
import 'socket_service.dart';

/// Streams the rider's position to dispatch for as long as the rider is
/// online — not only while the tracking screen is open — so auto-assignment
/// and customers see a live location.
///
/// On Android the stream runs as a foreground service (persistent
/// notification) and on iOS it uses background location updates, so tracking
/// keeps working with the screen off or another app (e.g. Google Maps
/// navigation) in front.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;
  Position? _lastPosition;
  DateTime? _lastSentAt;
  DateTime? _lastHttpAt;
  DateTime? _httpBackoffUntil;
  int _httpFailures = 0;
  String? _activeOrderId;

  bool _isTracking = false;
  bool _isStarting = false;
  bool get isTracking => _isTracking;

  /// A stationary rider emits no GPS events, which dispatch would read as
  /// "offline" — re-send the last fix at this interval.
  static const _heartbeat = Duration(seconds: 30);

  /// HTTP persistence (and socket fallback) cadence.
  static const _httpInterval = Duration(seconds: 30);

  final _locationController = StreamController<Position>.broadcast();
  Stream<Position> get onLocationUpdate => _locationController.stream;

  Position? get lastPosition => _lastPosition;
  String? get activeOrderId => _activeOrderId;

  /// Tags outgoing fixes with the order being delivered (null when idle).
  void setActiveOrder(String? orderId) => _activeOrderId = orderId;

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
      return _lastPosition;
    }
  }

  LocationSettings _buildSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // minimum 15m movement to emit
        intervalDuration: const Duration(seconds: 8),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'AquaGas Rider',
          notificationText: 'Sharing your live location with dispatch',
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 15,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );
  }

  /// Start streaming location updates. Safe to call repeatedly: a second call
  /// only updates the active order id.
  Future<void> startTracking({String? activeOrderId}) async {
    if (activeOrderId != null) _activeOrderId = activeOrderId;
    if (_isTracking || _isStarting) return;
    _isStarting = true;

    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) return;

      _isTracking = true;
      debugPrint('[Location] Started tracking');

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _buildSettings(),
      ).listen(
        _onPositionUpdate,
        onError: (e) => debugPrint('[Location] Stream error: $e'),
      );

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(_heartbeat, (_) => _onHeartbeat());
    } finally {
      _isStarting = false;
    }
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isTracking = false;
    _activeOrderId = null;
    _lastPosition = null;
    _lastSentAt = null;
    _lastHttpAt = null;
    _httpBackoffUntil = null;
    _httpFailures = 0;
    debugPrint('[Location] Stopped tracking');
  }

  void _onPositionUpdate(Position position) {
    final now = DateTime.now();

    // Skip jitter: only publish if moved enough, or if the last publish is
    // old enough that dispatch would otherwise think we've gone quiet.
    if (_lastPosition != null) {
      final moved = _distanceMeters(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          ) >=
          SocketConstants.minDistanceChangeMeters;
      final stale =
          _lastSentAt == null || now.difference(_lastSentAt!) >= _heartbeat;
      if (!moved && !stale) return;
    }

    _lastPosition = position;
    _lastSentAt = now;
    _locationController.add(position);
    _publish(position, now);
  }

  void _onHeartbeat() {
    final last = _lastPosition;
    if (last == null) return;
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!) < _heartbeat) {
      return;
    }
    _lastSentAt = now;
    _publish(last, now);
  }

  void _publish(Position p, DateTime now) {
    // Real-time channel for live maps.
    if (SocketService.instance.isConnected) {
      SocketService.instance.sendLocation(
        p.latitude,
        p.longitude,
        orderId: _activeOrderId,
        heading: p.heading,
        speed: p.speed,
        accuracy: p.accuracy,
      );
    }
    // Durable channel: also covers the case where the socket is down.
    unawaited(_postHttp(p, now));
  }

  Future<void> _postHttp(Position p, DateTime now) async {
    if (_httpBackoffUntil != null && now.isBefore(_httpBackoffUntil!)) return;
    if (_lastHttpAt != null && now.difference(_lastHttpAt!) < _httpInterval) {
      return;
    }
    _lastHttpAt = now;

    try {
      await ApiService.instance.post(ApiConstants.updateLocation, data: {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'lat': p.latitude,
        'lng': p.longitude,
        'heading': p.heading,
        'speed': p.speed,
        'accuracy': p.accuracy,
        if (_activeOrderId != null) 'order_id': _activeOrderId,
        'recorded_at': p.timestamp.toUtc().toIso8601String(),
      });
      _httpFailures = 0;
    } catch (e) {
      // Don't hammer an endpoint that is missing or failing: after three
      // misses in a row, stop trying for ten minutes.
      _httpFailures++;
      if (_httpFailures >= 3) {
        _httpBackoffUntil = now.add(const Duration(minutes: 10));
        _httpFailures = 0;
        debugPrint('[Location] HTTP location updates paused for 10 minutes');
      }
    }
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
