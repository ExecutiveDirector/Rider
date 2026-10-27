// lib/features/orders/order_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/navigation_launcher.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/config/routes.dart';
import '../../data/providers/order_provider.dart';
import '../../data/models/order_model.dart';
import '../chat/order_chat_screen.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _isCompleting = false;

  OrderModel? _findOrder() {
    final state = ref.watch(orderProvider);
    // Search active first, then completed
    for (final o in state.activeOrders) {
      if (o.id == widget.orderId) return o;
    }
    for (final o in state.completedOrders) {
      if (o.id == widget.orderId) return o;
    }
    return null;
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : null,
    ));
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.isEmpty) return _toast('Phone number not available');
    if (!await launchPhoneCall(phone)) _toast('Could not open phone dialler');
  }

  Future<void> _navigate(double lat, double lng) async {
    if (!await launchNavigation(lat, lng)) {
      _toast('Could not open a maps app', error: true);
    }
  }

  /// Where the rider is in the job: 0..6 (6 = ready to complete delivery).
  int _stepIndex(OrderModel order) {
    final p = order.riderProgress;
    if (order.status == OrderStatus.accepted) {
      if (p == 'arrived_pickup') return 2;
      if (p == 'en_route_pickup') return 1;
      return 0;
    }
    if (p == 'arrived_customer') return 5;
    if (p == 'en_route_delivery') return 4;
    return 3;
  }

  Widget _buildStepProgress(OrderModel order) {
    final done = _stepIndex(order);
    return Row(
      children: List.generate(6, (i) {
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: i == 5 ? 0 : 4),
            decoration: BoxDecoration(
              color: i <= done ? AppColors.primary : AppColors.divider,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  /// The single button for the rider's next step. Tapping it moves the order on.
  Widget _buildNextAction(OrderModel order) {
    final step = _stepIndex(order);
    const labels = [
      'On my way to the vendor',
      'Arrived at the vendor',
      'Confirm pickup',
      'On my way to the customer',
      'Arrived at the customer',
      'Complete delivery',
    ];
    const icons = [
      Icons.directions_bike_outlined,
      Icons.storefront_outlined,
      Icons.inventory_2_outlined,
      Icons.directions_bike_outlined,
      Icons.place_outlined,
      Icons.check_circle_outline,
    ];
    VoidCallback? action;
    switch (step) {
      case 0:
        action = () => _sendStep(order.id, 'en_route_pickup');
        break;
      case 1:
        action = () => _sendStep(order.id, 'arrived_pickup');
        break;
      case 2:
        action = () => _confirmPickup(order.id);
        break;
      case 3:
        action = () => _sendStep(order.id, 'en_route_delivery');
        break;
      case 4:
        action = () => _sendStep(order.id, 'arrived_customer');
        break;
      default:
        action = () => _deliverOrder(order.id);
    }
    return GradientButton(
      icon: icons[step],
      label: labels[step],
      loading: _isCompleting,
      onPressed: _isCompleting ? null : action,
    );
  }

  Future<void> _confirmPickup(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm pickup'),
        content: const Text(
          'Confirm you have collected the gas cylinder from the vendor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCompleting = true);
    final ok = await ref.read(orderProvider.notifier).pickupOrder(orderId);
    if (!mounted) return;
    setState(() => _isCompleting = false);
    if (!ok) {
      _toast(ref.read(orderProvider).error ?? 'Failed to update order.',
          error: true);
    }
  }

  Future<void> _sendStep(String orderId, String step) async {
    setState(() => _isCompleting = true);
    final ok = await ref.read(orderProvider.notifier).sendProgress(orderId, step);
    if (!mounted) return;
    setState(() => _isCompleting = false);
    if (!ok) {
      _toast(ref.read(orderProvider).error ?? 'Could not update progress.', error: true);
    }
  }

  /// Delivery is completed on its own screen, where the rider enters the
  /// customer's code, takes a photo and records cash / empty cylinders.
  Future<void> _deliverOrder(String orderId) async {
    final done = await Navigator.pushNamed<bool>(
      context,
      AppRoutes.proofOfDelivery,
      arguments: orderId,
    );
    if (done == true && mounted) {
      _toast('🎉 Delivery completed!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _findOrder();

    if (order == null) {
      // FIX: show a loading state briefly in case state hasn't settled yet,
      // rather than immediately showing "Order not found"
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // FIX: include pending (dispatched, not yet accepted) in actionable states
    final isActive = order.status == OrderStatus.accepted ||
        order.status == OrderStatus.inTransit;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Order #${order.orderNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            onPressed: () => _callCustomer(order.customerPhone),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusCard(order: order),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: _OrderProgressStepper(status: order.status),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Customer',
              children: [
                _DetailRow(Icons.person_outline, 'Name', order.customerName),
                _DetailRow(
                    Icons.phone_outlined,
                    'Phone',
                    order.customerPhone.isEmpty
                        ? 'Not available'
                        : order.customerPhone),
              ],
            ),
            const SizedBox(height: 16),
            if (order.vendorName != null ||
                order.pickupAddress != null ||
                order.hasPickupLocation) ...[
              _SectionCard(
                title: 'Pickup',
                trailing: TextButton.icon(
                  icon: const Icon(Icons.navigation_outlined, size: 16),
                  label: const Text('Navigate'),
                  onPressed: order.hasPickupLocation
                      ? () => _navigate(order.pickupLat!, order.pickupLng!)
                      : null,
                ),
                children: [
                  if (order.vendorName != null)
                    _DetailRow(Icons.storefront_outlined, 'Vendor',
                        order.vendorName!),
                  if (order.pickupAddress != null)
                    _DetailRow(Icons.location_on_outlined, 'Address',
                        order.pickupAddress!),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _SectionCard(
              title: 'Delivery',
              trailing: TextButton.icon(
                icon: const Icon(Icons.navigation_outlined, size: 16),
                label: const Text('Navigate'),
                onPressed: order.hasDeliveryLocation
                    ? () => _navigate(order.deliveryLat, order.deliveryLng)
                    : null,
              ),
              children: [
                _DetailRow(Icons.location_on_outlined, 'Address',
                    order.deliveryAddress),
                if (order.distanceKm != null)
                  _DetailRow(Icons.directions_outlined, 'Distance',
                      '${order.distanceKm!.toStringAsFixed(1)} km'),
                if (order.notes != null && order.notes!.isNotEmpty)
                  _DetailRow(Icons.notes_outlined, 'Notes', order.notes!),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Order',
              children: [
                _DetailRow(Icons.local_fire_department_outlined,
                    order.isGasItem ? 'Gas Type' : 'Item', order.gasType),
                _DetailRow(Icons.scale_outlined, 'Quantity',
                    order.isGasItem ? '${order.quantity} kg' : '${order.quantity}'),
                _DetailRow(Icons.attach_money_outlined, 'Total',
                    'KES ${order.totalAmount.toStringAsFixed(0)}'),
                if (order.riderEarning != null)
                  _DetailRow(Icons.account_balance_wallet_outlined,
                      'You earn', 'KES ${order.riderEarning!.toStringAsFixed(0)}'),
                _DetailRow(
                  Icons.payments_outlined,
                  'Payment',
                  order.isCod
                      ? (order.cashlessOnly
                          ? 'Pay on delivery — M-Pesa only (KES ${order.amountDue.toStringAsFixed(0)}). Do not take cash.'
                          : 'Pay on delivery — KES ${order.amountDue.toStringAsFixed(0)} by M-Pesa request (or cash)')
                      : (order.paymentMethod.isEmpty
                          ? 'Not specified'
                          : 'Prepaid (${order.paymentMethod})'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (isActive) ...[
              // Track and chat sit side by side; one big button always shows the
              // next step and moves the order forward when tapped.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text('Track'),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.liveTracking,
                        arguments: order.id,
                      ),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      label: const Text('Chat'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderChatScreen(
                              orderId: order.id, orderNumber: order.orderNumber),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStepProgress(order),
              const SizedBox(height: 12),
              _buildNextAction(order),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final OrderModel order;
  const _StatusCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_fire_department,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.gasType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  order.isGasItem ? '${order.quantity} kg cylinder' : 'Qty: ${order.quantity}',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.status.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Order progress stepper ────────────────────────────────────────────────

class _OrderProgressStepper extends StatelessWidget {
  final OrderStatus status;
  const _OrderProgressStepper({required this.status});

  static const _labels = ['Pending', 'Pickup', 'En Route', 'Delivered'];
  static const _icons = [
    Icons.inventory_2_outlined,
    Icons.storefront_outlined,
    Icons.two_wheeler_outlined,
    Icons.check_circle_outline,
  ];

  int get _currentIndex {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.inTransit:
        return 2;
      case OrderStatus.delivered:
        return 3;
      case OrderStatus.cancelled:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex;

    if (current < 0) {
      return Container(
        padding: const EdgeInsets.all(4),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.cancelled, size: 18),
            SizedBox(width: 8),
            Text('This order was cancelled',
                style: TextStyle(
                    color: AppColors.cancelled,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      );
    }

    return Row(
      children: List.generate(_labels.length, (i) {
        final done = i < current;
        final active = i == current;
        final circleColor = done
            ? AppColors.primary
            : active
                ? AppColors.primary.withOpacity(0.14)
                : AppColors.background;
        final borderColor =
            done || active ? AppColors.primary : AppColors.divider;
        final iconColor = done
            ? Colors.white
            : active
                ? AppColors.primary
                : AppColors.textHint;

        final dot = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleColor,
                border: Border.all(color: borderColor, width: active ? 2 : 1),
              ),
              child: Icon(done ? Icons.check : _icons[i],
                  size: 15, color: iconColor),
            ),
            const SizedBox(height: 4),
            Text(
              _labels[i],
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: done || active
                    ? AppColors.textPrimary
                    : AppColors.textHint,
              ),
            ),
          ],
        );

        if (i == _labels.length - 1) return dot;
        return Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dot,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    height: 2,
                    color: i < current ? AppColors.primary : AppColors.divider,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
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
      ),
    );
  }
}
