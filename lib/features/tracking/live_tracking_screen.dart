// lib/features/tracking/live_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/providers/tracking_provider.dart';
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

  Set<Marker> _buildMarkers(TrackingState tracking, OrderModel? order) {
    final markers = <Marker>{};

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

  Set<Polyline> _buildPolylines(TrackingState tracking) {
    if (tracking.routePoints.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: tracking.routePoints,
        color: AppColors.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(8)],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider);
    final order = _getOrder();

    // Animate to rider when position updates
    ref.listen(
      trackingProvider.select((s) => s.currentPosition),
      (prev, next) {
        if (next != null) _animateCameraToPosition(next);
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
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
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
            polylines: _buildPolylines(tracking),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Bottom order info panel
          if (order != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _TrackingInfoPanel(order: order),
            ),

          // Recenter button
          Positioned(
            right: 16,
            bottom: order != null ? 200 : 100,
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

class _TrackingInfoPanel extends StatelessWidget {
  final OrderModel order;
  const _TrackingInfoPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
        ],
      ),
    );
  }
}
