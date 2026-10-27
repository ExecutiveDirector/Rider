// lib/core/services/directions_service.dart
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../constants/api_constants.dart';

/// One turn-by-turn instruction.
class RouteStep {
  /// Plain-text instruction, e.g. "Turn left onto Mombasa Rd".
  final String instruction;

  /// Length of this step, e.g. "350 m".
  final String distanceText;

  /// Maneuver id ("turn-left", "roundabout-right", ...), if any. Uses the
  /// same ids the navigation banner already maps to icons.
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

/// Client for a free OSRM routing server (OpenStreetMap data, no API key).
/// Fails soft: any error returns null and the map simply shows no route.
class DirectionsService {
  DirectionsService._();
  static final DirectionsService instance = DirectionsService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'User-Agent': 'AquaGasRider/1.0'},
  ));

  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      // OSRM wants lon,lat order.
      final coords = '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}';
      final response = await _dio.get(
        '${ApiConstants.routingBaseUrl}/route/v1/driving/$coords',
        queryParameters: {
          'overview': 'full',
          'geometries': 'polyline', // precision 5
          'steps': 'true',
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final routes = data['routes'] as List? ?? [];
      if (routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final distanceM = (route['distance'] as num).toDouble();
      final durationS = (route['duration'] as num).toDouble();
      final legs = route['legs'] as List? ?? [];
      final rawSteps = legs.isEmpty
          ? const []
          : ((legs.first as Map<String, dynamic>)['steps'] as List? ?? []);

      // OSRM attaches each maneuver to the START of its step. The banner shows
      // "what's coming, and how far", so every step carries the NEXT step's
      // maneuver together with this step's length and end point.
      final steps = <RouteStep>[];
      for (var i = 0; i < rawSteps.length; i++) {
        final m = rawSteps[i] as Map<String, dynamic>;
        final isLast = i + 1 >= rawSteps.length;
        final upcoming = isLast ? m : rawSteps[i + 1] as Map<String, dynamic>;
        final maneuver =
            (upcoming['maneuver'] as Map<String, dynamic>?) ?? const {};
        final type = maneuver['type'] as String? ?? '';
        final modifier = maneuver['modifier'] as String?;

        LatLng end = destination;
        final loc = maneuver['location'] as List?;
        if (!isLast && loc != null && loc.length >= 2) {
          end = LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble());
        }
        steps.add(RouteStep(
          instruction:
              _instruction(type, modifier, upcoming['name'] as String? ?? ''),
          distanceText: _distanceText((m['distance'] as num?)?.toDouble() ?? 0),
          maneuver: _maneuverId(type, modifier),
          end: end,
        ));
      }

      return DirectionsResult(
        polylinePoints: _decodePolyline(route['geometry'] as String),
        distanceText: _distanceText(distanceM),
        durationText: _durationText(durationS),
        distanceKm: distanceM / 1000.0,
        durationMinutes: (durationS / 60).round(),
        steps: steps,
      );
    } catch (_) {
      // Network hiccup, rate limit, malformed response, etc. — fail soft.
      return null;
    }
  }

  String _distanceText(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  String _durationText(double seconds) {
    final mins = (seconds / 60).round();
    if (mins < 1) return '1 min';
    if (mins < 60) return '$mins min${mins == 1 ? '' : 's'}';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  /// OSRM type/modifier → the maneuver ids the banner knows about.
  String? _maneuverId(String type, String? modifier) {
    if (type == 'roundabout' || type == 'rotary' || type == 'roundabout turn') {
      return modifier != null && modifier.contains('left')
          ? 'roundabout-left'
          : 'roundabout-right';
    }
    if (type == 'merge') return 'merge';
    switch (modifier) {
      case 'left':
        return 'turn-left';
      case 'right':
        return 'turn-right';
      case 'slight left':
        return 'turn-slight-left';
      case 'slight right':
        return 'turn-slight-right';
      case 'sharp left':
        return 'turn-sharp-left';
      case 'sharp right':
        return 'turn-sharp-right';
      case 'uturn':
        return 'uturn-left';
      default:
        return null; // straight / unknown → straight arrow
    }
  }

  String _instruction(String type, String? modifier, String name) {
    final road = name.isEmpty ? '' : ' onto $name';
    final dir = modifier == null
        ? ''
        : modifier == 'uturn'
            ? 'U-turn'
            : modifier;
    switch (type) {
      case 'depart':
        return name.isEmpty ? 'Start your trip' : 'Head out on $name';
      case 'arrive':
        return 'Arrive at your destination';
      case 'roundabout':
      case 'rotary':
      case 'roundabout turn':
        return 'Enter the roundabout and continue$road';
      case 'merge':
        return 'Merge$road';
      case 'fork':
        return dir.isEmpty ? 'Keep to the fork$road' : 'Keep $dir at the fork$road';
      case 'end of road':
        return dir.isEmpty ? 'Turn$road' : 'Turn $dir$road';
      case 'continue':
      case 'new name':
        return dir.isEmpty || dir == 'straight'
            ? 'Continue${name.isEmpty ? '' : ' on $name'}'
            : 'Continue $dir$road';
      default:
        if (dir.isEmpty || dir == 'straight') {
          return 'Continue${name.isEmpty ? '' : ' on $name'}';
        }
        return dir == 'U-turn' ? 'Make a U-turn$road' : 'Turn $dir$road';
    }
  }

  /// Standard encoded-polyline decoding (precision 5).
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
