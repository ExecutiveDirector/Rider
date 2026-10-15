// lib/core/utils/geo_utils.dart
import 'dart:math' as math;

/// Straight-line distance in metres between two coordinates.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a.toDouble())));
}

/// "850 m" / "2.4 km".
String formatDistance(double meters) =>
    meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

/// Rough ride time on a motorbike in Nairobi traffic (~18 km/h average on
/// straight-line distance x 1.35 for road winding). A hint, not a promise.
int roughMinutes(double straightMeters) =>
    ((straightMeters * 1.35) / 1000 / 18 * 60).ceil().clamp(1, 180).toInt();
