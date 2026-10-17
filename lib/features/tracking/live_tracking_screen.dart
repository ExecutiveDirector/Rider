// lib/features/tracking/live_tracking_screen.dart
import 'safety_sheet.dart';
import 'order_problem_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/config/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/navigation_launcher.dart';
import '../../core/widgets/pulse_dot.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/providers/tracking_provider.dart';
import '../../data/providers/directions_provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/models/order_model.dart';

/// Where the rider is heading right now: the vendor until the cylinder has
/// been collected, then the customer.
class _Target {
  final LatLng point;
  final String title;
  final String address;
  final bool isPickup;
  const _Target({
    required this.point,
    required this.title,
    required this.address,
    required this.isPickup,
  });
}

_Target? _targetFor(OrderModel o) {
  if (o.status == OrderStatus.accepted && o.hasPickupLocation) {
    return _Target(
      point: LatLng(o.pickupLat!, o.pickupLng!),
      title: o.vendorName ?? 'Pickup point',
      address: o.pickupAddress ?? '',
      isPickup: true,
    );
  }
  if (o.hasDeliveryLocation) {
    return _Target(
      point: LatLng(o.deliveryLat, o.deliveryLng),
      title: o.customerName,
      address: o.deliveryAddress,
      isPickup: false,
    );
  }
  return null;
}

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const LiveTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final Completer<GoogleMapController> _mapCompleter = Completer();
  GoogleMapController? _mapController;
  bool _busy = false;

  static const _defaultPosition = LatLng(-1.2921, 36.8219); // Nairobi

  late final TrackingNotifier _tracking;
  late final DirectionsNotifier _directions;

  @override
  void initState() {
    super.initState();
    // Cache the notifiers: ref must not be used inside dispose().
    _tracking = ref.read(trackingProvider.notifier);
    _directions = ref.read(directionsProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tracking.startTracking(widget.orderId);
    });
  }

  @override
  void dispose() {
    // Detaches the map only; the location service keeps running while the
    // rider is online, so dispatch doesn't lose them when this closes.
    _tracking.stopTracking();
    // A stale route/ETA from this delivery must not leak into the next one.
    _directions.clear();
    _mapController?.dispose();
    super.dispose();
  }

  OrderModel? _getOrder() {
    final state = ref.watch(orderProvider);
    for (final o in state.activeOrders) {
      if (o.id == widget.orderId) return o;
    }
    return null;
  }

  void _animateCameraToPosition(LatLng pos) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.isEmpty) return _toast('Phone number not available');
    if (!await launchPhoneCall(phone)) _toast('Could not open phone dialler');
  }

  Future<void> _navigate(_Target target) async {
    final ok = await launchNavigation(
        target.point.latitude, target.point.longitude);
    if (!ok) _toast('Could not open a maps app', error: true);
  }

  Future<void> _confirmPickup(OrderModel order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm pickup'),
        content: const Text(
            'Confirm you have collected the gas cylinder from the vendor.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final success =
        await ref.read(orderProvider.notifier).pickupOrder(order.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!success) {
      _toast(ref.read(orderProvider).error ?? 'Failed to update order.',
          error: true);
    }
  }

  Future<void> _completeDelivery(OrderModel order) async {
    final done = await Navigator.pushNamed<bool>(
      context,
      AppRoutes.proofOfDelivery,
      arguments: order.id,
    );
    if (done == true && mounted) Navigator.pop(context);
  }

  Set<Marker> _buildMarkers(
      TrackingState tracking, OrderModel? order, _Target? target) {
    final markers = <Marker>{};

    // "You are here" stays the universal map-blue every rider already reads
    // instantly — brand color goes on the chrome and route instead.
    if (tracking.currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: tracking.currentPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        rotation: tracking.heading ?? 0,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }

    if (order != null && target != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: target.point,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          target.isPickup
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(title: target.title, snippet: target.address),
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
    final target = order == null ? null : _targetFor(order);
    final topInset = MediaQuery.of(context).padding.top;

    // Follow the rider, keep the route/ETA to the current target fresh and
    // advance the turn-by-turn step. updateRoute throttles itself (distance +
    // interval) so calling it on every GPS tick is safe; advanceStep is a
    // cheap local calculation.
    ref.listen(
      trackingProvider.select((s) => s.currentPosition),
      (prev, next) {
        if (next == null) return;
        _animateCameraToPosition(next);
        final o = _getOrder();
        final t = o == null ? null : _targetFor(o);
        if (t != null) {
          ref
              .read(directionsProvider.notifier)
              .updateRoute(origin: next, destination: t.point);
          ref.read(directionsProvider.notifier).advanceStep(next);
        }
      },
    );

    // Stage changed (pickup confirmed): re-route to the new target right
    // away instead of waiting for the next GPS fix.
    ref.listen(
      orderProvider.select((s) {
        for (final o in s.activeOrders) {
          if (o.id == widget.orderId) return o.status;
        }
        return null;
      }),
      (prev, next) {
        final pos = ref.read(trackingProvider).currentPosition;
        final o = _getOrder();
        final t = o == null ? null : _targetFor(o);
        if (pos != null && t != null) {
          ref
              .read(directionsProvider.notifier)
              .updateRoute(origin: pos, destination: t.point);
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulseDot(color: AppColors.primary, size: 7),
              SizedBox(width: 8),
              Text(
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
              if (!_mapCompleter.isCompleted) {
                _mapCompleter.complete(controller);
              }
              _mapController = controller;
            },
            markers: _buildMarkers(tracking, order, target),
            polylines: _buildPolylines(directions),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Next-maneuver + ETA banner
          if (order != null)
            Positioned(
              top: topInset + kToolbarHeight + 8,
              left: 16,
              right: 16,
              child: _NavBanner(directions: directions, target: target),
            ),

          // Bottom order info panel
          if (order != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _TrackingInfoPanel(
                order: order,
                target: target,
                busy: _busy,
                onCall: () => _callCustomer(order.customerPhone),
                onNavigate: target == null ? null : () => _navigate(target),
                onPrimary: () => order.status == OrderStatus.accepted
                    ? _confirmPickup(order)
                    : _completeDelivery(order),
              ),
            ),

          // Safety / help
          Positioned(
            right: 16,
            bottom: order != null ? 352 : 152,
            child: FloatingActionButton.small(
              heroTag: 'safety_fab',
              onPressed: () => showSafetySheet(
                context,
                lat: tracking.currentPosition?.latitude,
                lng: tracking.currentPosition?.longitude,
                orderNumber: order?.orderNumber,
                onProblem: order == null
                    ? null
                    : () async {
                        final removed = await showOrderProblemSheet(
                          context,
                          ref,
                          order,
                          lat: tracking.currentPosition?.latitude,
                          lng: tracking.currentPosition?.longitude,
                        );
                        if (removed == true && mounted) Navigator.pop(context);
                      },
                problemTitle: order?.status == OrderStatus.inTransit
                    ? 'Delivery failed'
                    : "I can't deliver this order",
                problemSubtitle: order?.status == OrderStatus.inTransit
                    ? 'Customer unreachable, refused, wrong address…'
                    : 'Hand it back so another rider can take it',
              ),
              backgroundColor: Colors.white,
              child: const Icon(Icons.shield_outlined, color: AppColors.error),
            ),
          ),

          // Recenter button
          Positioned(
            right: 16,
            bottom: order != null ? 300 : 100,
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

// ─── Maneuver + ETA banner ─────────────────────────────────────────────────

IconData _maneuverIcon(String? maneuver) {
  switch (maneuver) {
    case 'turn-left':
      return Icons.turn_left;
    case 'turn-right':
      return Icons.turn_right;
    case 'turn-slight-left':
      return Icons.turn_slight_left;
    case 'turn-slight-right':
      return Icons.turn_slight_right;
    case 'turn-sharp-left':
      return Icons.turn_sharp_left;
    case 'turn-sharp-right':
      return Icons.turn_sharp_right;
    case 'uturn-left':
      return Icons.u_turn_left;
    case 'uturn-right':
      return Icons.u_turn_right;
    case 'roundabout-left':
      return Icons.roundabout_left;
    case 'roundabout-right':
      return Icons.roundabout_right;
    case 'merge':
      return Icons.merge;
    default:
      return Icons.straight;
  }
}

String _formatMeters(double? m) {
  if (m == null) return '';
  if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
  // Round to the nearest 10 m so the number doesn't flicker every GPS tick.
  return '${((m / 10).round() * 10)} m';
}

class _NavBanner extends StatelessWidget {
  final DirectionsState directions;
  final _Target? target;
  const _NavBanner({required this.directions, required this.target});

  @override
  Widget build(BuildContext context) {
    final hasData =
        directions.durationText != null && directions.distanceText != null;
    final step = directions.currentStep;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.brightGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_maneuverIcon(step.maneuver),
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.instruction.isEmpty
                            ? 'Continue'
                            : step.instruction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (directions.metersToNextStep != null)
                        Text(
                          'in ${_formatMeters(directions.metersToNextStep)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (step == null)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.brightGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.navigation,
                      color: Colors.white, size: 18),
                ),
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
                Flexible(
                  child: Text(
                    target?.isPickup == true ? 'to pickup' : 'to customer',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 12.5),
                  ),
                ),
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
                Text(
                  target == null
                      ? 'No map location for this order'
                      : 'In-app route unavailable — use Navigate',
                  style: const TextStyle(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bottom tracking info panel ────────────────────────────────────────────

class _TrackingInfoPanel extends StatelessWidget {
  final OrderModel order;
  final _Target? target;
  final bool busy;
  final VoidCallback onCall;
  final VoidCallback? onNavigate;
  final VoidCallback onPrimary;

  const _TrackingInfoPanel({
    required this.order,
    required this.target,
    required this.busy,
    required this.onCall,
    required this.onNavigate,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final atPickup = order.status == OrderStatus.accepted;
    final title = target?.title ?? order.customerName;
    final subtitle = target?.address.isNotEmpty == true
        ? target!.address
        : order.deliveryAddress;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            atPickup ? 'STEP 1 OF 2 · PICK UP' : 'STEP 2 OF 2 · DELIVER',
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  atPickup
                      ? Icons.storefront_outlined
                      : Icons.local_fire_department_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KES ${(order.isCod ? order.amountDue : order.totalAmount).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  if (order.isCod)
                    const Text(
                      'collect cash',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor:
                    atPickup ? AppColors.accepted : AppColors.delivered,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(atPickup
                      ? Icons.inventory_2_outlined
                      : Icons.check_circle_outline),
              label: Text(
                atPickup ? 'Confirm pickup' : 'Complete delivery',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
