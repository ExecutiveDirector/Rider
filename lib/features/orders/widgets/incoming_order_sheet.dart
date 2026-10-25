// lib/features/orders/widgets/incoming_order_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/config/routes.dart';
import '../../../core/services/order_alert_sound_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/widgets/cancel_reason_dialog.dart';
import '../../../data/models/order_model.dart';
import '../../../data/providers/order_provider.dart';

class IncomingOrderSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  const IncomingOrderSheet({super.key, required this.order});

  @override
  ConsumerState<IncomingOrderSheet> createState() => _IncomingOrderSheetState();
}

class _IncomingOrderSheetState extends ConsumerState<IncomingOrderSheet>
    with SingleTickerProviderStateMixin {
  static const _defaultSeconds = 20;

  // The countdown is computed from a fixed deadline rather than by counting
  // ticks, so a delayed timer (busy frame, backgrounded app) can't stretch
  // the offer beyond what dispatch allowed.
  late DateTime _deadline;
  late final int _totalSeconds;
  int _remaining = _defaultSeconds;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  bool _isAccepting = false;
  // Guards against auto-reject / external dismissal firing after the rider
  // has already accepted or rejected.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // Rings continuously — like an incoming call — for as long as this
    // sheet is on screen. Stopped in dispose(), which fires on accept,
    // reject, timeout and external dismissal alike.
    OrderAlertSoundService.instance.play();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Honour the server's offer window when it sends one, but clamp it: the
    // phone's clock may be off, and an offer should never be shorter than the
    // rider can physically react to, or longer than dispatch will wait.
    var seconds = _defaultSeconds;
    final expiresAt = widget.order.offerExpiresAt;
    if (expiresAt != null) {
      seconds =
          expiresAt.difference(DateTime.now()).inSeconds.clamp(8, 45).toInt();
    }
    _totalSeconds = seconds;
    _remaining = seconds;
    _deadline = DateTime.now().add(Duration(seconds: seconds));
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (_deadline.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil();
      if (left <= 0) {
        t.cancel();
        _reject(auto: true);
      } else if (mounted) {
        setState(() => _remaining = left);
      }
    });
  }

  Future<void> _accept() async {
    if (_handled) return;
    _handled = true;
    _timer?.cancel();
    setState(() => _isAccepting = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok =
        await ref.read(orderProvider.notifier).acceptOrder(widget.order.id);
    if (!mounted) return;

    navigator.pop();
    if (ok) {
      navigator.pushNamed(AppRoutes.orderDetails, arguments: widget.order.id);
    } else {
      // Previously the sheet closed as if the accept had worked. Tell the
      // rider what actually happened.
      final reason = ref.read(orderProvider).error;
      messenger?.showSnackBar(SnackBar(
        content: Text(reason == null || reason.isEmpty
            ? 'Could not accept this order. It may have been taken.'
            : reason),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _reject({bool auto = false, String? customReason}) {
    if (_handled) return;
    _handled = true;
    _timer?.cancel();
    ref.read(orderProvider.notifier).rejectOrder(
          widget.order.id,
          reason: auto
              ? 'Auto-rejected (timeout)'
              : (customReason ?? 'Rider declined'),
        );
    if (mounted) Navigator.of(context).pop();
  }

  /// The offer disappeared underneath the rider (cancelled, reassigned, or
  /// answered from another screen). Close the sheet and say why.
  void _dismissedExternally() {
    if (_handled) return;
    _handled = true;
    _timer?.cancel();
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(const SnackBar(
      content: Text('That order is no longer available.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Manual reject: pause the countdown while the reason dialog is open (an
  /// auto-reject firing underneath it would pop the dialog instead of the
  /// sheet), then reject with that reason. If the rider backs out, the
  /// countdown resumes with the time that was left (never less than 5s).
  Future<void> _onRejectPressed() async {
    _timer?.cancel();
    final reason = await CancelReasonDialog.show(context);
    if (!mounted || _handled) return;
    if (reason == null) {
      final resumeFor = _remaining < 5 ? 5 : _remaining;
      _deadline = DateTime.now().add(Duration(seconds: resumeFor));
      _startTimer();
      return;
    }
    _reject(customReason: reason);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    OrderAlertSoundService.instance.stop();
    super.dispose();
  }

  /// "2.4 km to pickup · ~9 min" (rider -> pickup), plus pickup -> customer
  /// when both are known. Straight-line estimates; null without a GPS fix.
  String? _awayLabel(OrderModel order) {
    final me = LocationService.instance.lastPosition;
    if (me == null) return null;
    final parts = <String>[];
    if (order.hasPickupLocation) {
      final d = haversineMeters(
          me.latitude, me.longitude, order.pickupLat!, order.pickupLng!);
      parts.add('${formatDistance(d)} to pickup · ~${roughMinutes(d)} min');
      if (order.hasDeliveryLocation) {
        final t = haversineMeters(order.pickupLat!, order.pickupLng!,
            order.deliveryLat, order.deliveryLng);
        parts.add('${formatDistance(t)} trip');
      }
    } else if (order.hasDeliveryLocation) {
      final d = haversineMeters(
          me.latitude, me.longitude, order.deliveryLat, order.deliveryLng);
      parts.add('${formatDistance(d)} to customer · ~${roughMinutes(d)} min');
    }
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    // Close if the offer is withdrawn while the sheet is open.
    ref.listen<OrderModel?>(
      orderProvider.select((s) => s.incomingOrder),
      (prev, next) {
        if (next == null || next.id != widget.order.id) {
          _dismissedExternally();
        }
      },
    );

    final order = widget.order;
    final progress = (_remaining / _totalSeconds).clamp(0.0, 1.0).toDouble();
    final urgent = progress <= 0.4;
    final pickupLine = [
      if (order.vendorName != null && order.vendorName!.isNotEmpty)
        order.vendorName!,
      if (order.pickupAddress != null && order.pickupAddress!.isNotEmpty)
        order.pickupAddress!,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: AppColors.brightGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header with timer
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppColors.brightGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary
                                  .withOpacity(0.25 + 0.2 * _pulseCtrl.value),
                              blurRadius: 8 + 10 * _pulseCtrl.value,
                              spreadRadius: 1 + 2 * _pulseCtrl.value,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.local_fire_department,
                            color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'New Order!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            backgroundColor: AppColors.divider,
                            color: urgent ? AppColors.error : AppColors.warning,
                            strokeWidth: 3.5,
                          ),
                          Text(
                            '$_remaining',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: urgent
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                if (_awayLabel(order) != null) ...[
                  _InfoRow(
                    icon: Icons.near_me_outlined,
                    label: 'Away',
                    value: _awayLabel(order)!,
                  ),
                  const SizedBox(height: 10),
                ],
                if (pickupLine.isNotEmpty) ...[
                  _InfoRow(
                    icon: Icons.storefront_outlined,
                    label: 'Pick up',
                    value: pickupLine,
                  ),
                  const SizedBox(height: 10),
                ],
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Customer',
                  value: order.customerName,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Deliver to',
                  value: order.deliveryAddress,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Gas',
                  value:
                      '${order.quantity.toStringAsFixed(0)} × ${order.gasType}',
                ),
                if (order.distanceKm != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.directions_outlined,
                    label: 'Distance',
                    value: '${order.distanceKm!.toStringAsFixed(1)} km',
                  ),
                ],

                const SizedBox(height: 16),

                // Earnings highlight. Only labelled "You earn" when the
                // backend actually sends the rider's share; otherwise show
                // the order total honestly rather than implying it is pay.
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: AppColors.earnGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.riderEarning != null ? 'You earn' : 'Order total',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        'KES ${(order.riderEarning ?? order.totalAmount).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                if (order.isCod) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.cashlessOnly
                                ? 'Pay on delivery — M-Pesa request, KES ${order.amountDue.toStringAsFixed(0)}'
                                : 'Pay on delivery — KES ${order.amountDue.toStringAsFixed(0)} (M-Pesa or cash)',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isAccepting ? null : _onRejectPressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GradientButton(
                        label: 'Accept Order',
                        loading: _isAccepting,
                        onPressed: _isAccepting ? null : _accept,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
