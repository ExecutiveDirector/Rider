// lib/features/home/demand_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/growth_models.dart';
import '../../data/providers/growth_provider.dart';

/// Heat-map of where customers ordered in the last few hours, so idle riders
/// can position themselves. Cells are ~1 km; no individual addresses are shown.
class DemandMapScreen extends ConsumerStatefulWidget {
  const DemandMapScreen({super.key});

  @override
  ConsumerState<DemandMapScreen> createState() => _DemandMapScreenState();
}

class _DemandMapScreenState extends ConsumerState<DemandMapScreen> {
  static const _nairobi = LatLng(-1.2921, 36.8219);
  LatLng _center = _nairobi;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p != null && mounted) {
        setState(() => _center = LatLng(p.latitude, p.longitude));
        _controller?.animateCamera(CameraUpdate.newLatLng(_center));
      }
    } catch (_) {
      // Stay on the Nairobi default.
    }
  }

  Set<Circle> _circles(List<DemandZone> zones) => {
        for (final (i, z) in zones.indexed)
          Circle(
            circleId: CircleId('z$i'),
            center: LatLng(z.latitude, z.longitude),
            radius: z.radiusM,
            fillColor: Color.lerp(const Color(0xFFFFC107),
                    const Color(0xFFE53935), z.intensity)!
                .withOpacity(0.25 + 0.35 * z.intensity),
            strokeColor: const Color(0xFFE53935).withOpacity(0.5),
            strokeWidth: 1,
          ),
      };

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zones = ref.watch(demandZonesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Busy areas'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(demandZonesProvider),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 12),
            onMapCreated: (c) => _controller = c,
            circles: zones.maybeWhen(data: _circles, orElse: () => {}),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: zones.when(
                loading: () => const Text('Loading demand…'),
                error: (_, __) => const Text(
                    "Couldn't load busy areas. Pull refresh to retry."),
                data: (z) => Text(
                  z.isEmpty
                      ? 'No busy areas right now. Check back soon.'
                      : 'Red = most orders in the last 3 hours. Top area: ${z.first.count} orders.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
