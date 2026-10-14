// lib/core/services/directions_service.dart
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/api_constants.dart';

/// One turn-by-turn instruction from the Directions API.
class RouteStep {
  /// Plain-text instruction, e.g. "Turn left onto Mombasa Rd".
  final String instruction;

  /// Length of this step, e.g. "350 m".
  final String distanceText;

  /// Google maneuver id ("turn-left", "roundabout-right", ...), if any.
  final String? maneuver;

  /// Where this step ends — reaching it means the maneuver is done.
  final LatLng end;

  const RouteStep({
    required this.instruction,
    required this.distanceText,
    required this.end,
    this.maneuver,
  });
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distanceText;
  final String durationText;
  final double distanceKm;
  final int durationMinutes;
  final List<RouteStep> steps;

  const DirectionsResult({
    required this.polylinePoints,
    required this.distanceText,
    required this.durationText,
    required this.distanceKm,
    required this.durationMinutes,
    this.steps = const [],
  });
}

/// Thin client around the Google Directions REST API.
///
/// NOTE: this calls Google directly from the device using
/// [ApiConstants.directionsApiKey]. That's the fastest path to ship, but it
/// does mean the key ships inside the APK. Restrict the key in Cloud
/// Console (Directions API only + Android package/SHA-1 + iOS bundle ID).
/// If you'd rather not expose a Maps key client-side at all, the safer
/// long-term move is a tiny backend proxy endpoint that calls Directions
/// server-side and forwards just the decoded result — happy to wire that
/// up instead if you'd prefer.
class DirectionsService {
  DirectionsService._();
  static final DirectionsService instance = DirectionsService._();

  final Dio _dio = Dio();
  static const _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (ApiConstants.directionsApiKey.isEmpty) {
      return null; // No key configured — caller falls back gracefully.
    }

    try {
      final response = await _dio.get(_baseUrl, queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'region': 'ke',
        'key': ApiConstants.directionsApiKey,
      });

      final data = response.data as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final routes = data['routes'] as List? ?? [];
      if (routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List? ?? [];
      if (legs.isEmpty) return null;
      final leg = legs.first as Map<String, dynamic>;

      final overviewPolyline = (route['overview_polyline']
          as Map<String, dynamic>)['points'] as String;

      final steps = <RouteStep>[];
      for (final raw in (leg['steps'] as List? ?? [])) {
        final m = raw as Map<String, dynamic>;
        final end = m['end_location'] as Map<String, dynamic>;
        steps.add(RouteStep(
          instruction: _stripHtml(m['html_instructions'] as String? ?? ''),
          distanceText:
              (m['distance'] as Map<String, dynamic>?)?['text'] as String? ??
                  '',
          maneuver: m['maneuver'] as String?,
          end: LatLng(
            (end['lat'] as num).toDouble(),
            (end['lng'] as num).toDouble(),
          ),
        ));
      }

      return DirectionsResult(
        polylinePoints: _decodePolyline(overviewPolyline),
        distanceText: leg['distance']['text'] as String,
        durationText: leg['duration']['text'] as String,
        distanceKm: (leg['distance']['value'] as num) / 1000.0,
        durationMinutes: ((leg['duration']['value'] as num) / 60).round(),
        steps: steps,
      );
    } catch (_) {
      // Network hiccup, quota error, malformed response, etc. — fail soft.
      return null;
    }
  }

  /// Directions returns instructions as HTML ("Turn <b>left</b> onto ...",
  /// optionally followed by a <div> with extra context). Reduce to plain text.
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<div[^>]*>.*?</div>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Standard Google encoded-polyline decoding algorithm.
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
