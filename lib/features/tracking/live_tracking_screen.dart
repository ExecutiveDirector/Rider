// lib/features/tracking/live_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/pulse_dot.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/providers/tracking_provider.dart';
import '../../data/providers/directions_provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/models/order_model.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const LiveTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final Completer<GoogleMapController> _mapCompleter = Completer();
  GoogleMapController? _mapController;

  static const _defaultPosition = LatLng(-1.2921, 36.8219); // Nairobi

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackingProvider.notifier).startTracking(widget.orderId);
    });
  }

  @override
  void dispose() {
    ref.read(trackingProvider.notifier).stopTracking();
    // FIX: previously built but never wired up anywhere — clear it here so
    // a stale route/ETA from this delivery doesn't leak into the next one.
    ref.read(directionsProvider.notifier).clear();
    _mapController?.dispose();
    super.dispose();
  }

  OrderModel? _getOrder() {
    final state = ref.watch(orderProvider);
    try {
      return state.activeOrders.firstWhere((o) => o.id == widget.orderId);
    } catch (_) {
      return null;
    }
  }

  void _animateCameraToPosition(LatLng pos) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available')),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialler')),
        );
      }
    }
  }

  Future<void> _openExternalMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Set<Marker> _buildMarkers(TrackingState tracking, OrderModel? order) {
    final markers = <Marker>{};

    // "You are here" stays the universal map-blue every rider already reads
    // instantly — brand color goes on the chrome and route instead, not on
    // the one marker that needs to be recognized at a glance while riding.
    if (tracking.currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: tracking.currentPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }

    if (order != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(order.deliveryLat, order.deliveryLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: order.customerName,
          snippet: order.deliveryAddress,
        ),
      ));
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(DirectionsState directions) {
    if (directions.routePoints.length < 2) return {};
    // A soft white casing under the brand-green line reads as a proper
    // navigation route rather than a plain single-color stroke.
    return {
      Polyline(
        polylineId: const PolylineId('route_casing'),
        points: directions.routePoints,
        color: Colors.white,
        width: 8,
        zIndex: 1,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: directions.routePoints,
        color: AppColors.primary,
        width: 5,
        zIndex: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider);
    final directions = ref.watch(directionsProvider);
    final order = _getOrder();
    final topInset = MediaQuery.of(context).padding.top;

    // Animate to rider when position updates, and keep the route/ETA to the
    // destination current. DirectionsNotifier throttles internally (min
    // distance + min interval) so this is safe to call on every GPS tick.
    ref.listen(
      trackingProvider.select((s) => s.currentPosition),
      (prev, next) {
        if (next == null) return;
        _animateCameraToPosition(next);
        if (order != null) {
          ref.read(directionsProvider.notifier).updateRoute(
                origin: next,
                destination: LatLng(order.deliveryLat, order.deliveryLng),
              );
        }
      },
    );

    final initialPosition = tracking.currentPosition ?? _defaultPosition;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PulseDot(color: AppColors.primary, size: 7),
              const SizedBox(width: 8),
              const Text(
                'Live Tracking',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapCompleter.complete(controller);
              _mapController = controller;
            },
            markers: _buildMarkers(tracking, order),
            polylines: _buildPolylines(directions),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ETA / distance banner — the live-tracking payoff: real data from
          // directionsProvider, which previously had no UI consuming it.
          if (order != null)
            Positioned(
              top: topInset + kToolbarHeight + 8,
              left: 16,
              right: 16,
              child: _EtaBanner(directions: directions),
            ),

          // Bottom order info panel
          if (order != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _TrackingInfoPanel(
                order: order,
                onCall: () => _callCustomer(order.customerPhone),
                onNavigate: () =>
                    _openExternalMaps(order.deliveryLat, order.deliveryLng),
              ),
            ),

          // Recenter button
          Positioned(
            right: 16,
            bottom: order != null ? 236 : 100,
            child: FloatingActionButton.small(
              onPressed: () {
                if (tracking.currentPosition != null) {
                  _animateCameraToPosition(tracking.currentPosition!);
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ETA / distance banner ─────────────────────────────────────────────────

class _EtaBanner extends StatelessWidget {
  final DirectionsState directions;
  const _EtaBanner({required this.directions});

  @override
  Widget build(BuildContext context) {
    final hasData = directions.durationText != null &&
        directions.distanceText != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.brightGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          if (hasData) ...[
            Text(
              directions.durationText!,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Text('to destination',
                style: TextStyle(color: AppColors.textHint, fontSize: 12.5)),
            const Spacer(),
            Text(
              directions.distanceText!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ] else if (directions.isLoading) ...[
            const Text(
              'Calculating route…',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            const Spacer(),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else ...[
            const Text(
              'Route unavailable',
              style: TextStyle(
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bottom tracking info panel ────────────────────────────────────────────

class _TrackingInfoPanel extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onCall;
  final VoidCallback onNavigate;

  const _TrackingInfoPanel({
    required this.order,
    required this.onCall,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'KES ${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call, size: 17),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: 'Navigate',
                  icon: Icons.navigation,
                  height: 46,
                  onPressed: onNavigate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
