// lib/core/constants/socket_constants.dart

class SocketConstants {
  SocketConstants._();

  // --- Driver emits ---
  static const String registerDriver = 'registerDriver';
  static const String locationUpdate = 'locationUpdate';
  static const String acceptOrder = 'acceptOrder';
  static const String rejectOrder = 'rejectOrder';
  static const String completeOrder = 'completeOrder';
  static const String driverOnline = 'driverOnline';
  static const String driverOffline = 'driverOffline';

  // --- Backend emits (driver listens) ---
  static const String newOrder = 'newOrder';
  static const String orderCancelled = 'orderCancelled';
  static const String orderUpdated = 'orderUpdated';
  static const String paymentReceived = 'paymentReceived';
  static const String connected = 'connect';
  static const String disconnected = 'disconnect';
  static const String connectError = 'connect_error';

  // Location update interval (ms) — battery-friendly
  static const int locationUpdateIntervalMs = 8000; // every 8 seconds
  static const double minDistanceChangeMeters = 20; // or if moved 20m
}
