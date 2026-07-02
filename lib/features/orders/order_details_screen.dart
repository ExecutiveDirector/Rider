// lib/features/orders/order_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/routes.dart';
import '../../data/providers/order_provider.dart';
import '../../data/models/order_model.dart';

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

  Future<void> _callCustomer(String phone) async {
    // FIX: guard against empty phone number
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

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _deliverOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Complete Delivery?'),
        content: const Text(
          'Confirm the gas cylinder has been delivered to the customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCompleting = true);
    final success =
        await ref.read(orderProvider.notifier).deliverOrder(orderId);
    setState(() => _isCompleting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Delivery completed!'),
          backgroundColor: AppColors.success,
        ),
      );
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
            _SectionCard(
              title: 'Delivery',
              trailing: TextButton.icon(
                icon: const Icon(Icons.navigation_outlined, size: 16),
                label: const Text('Navigate'),
                onPressed: () =>
                    _openMaps(order.deliveryLat, order.deliveryLng),
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
                _DetailRow(Icons.local_fire_department_outlined, 'Gas Type',
                    order.gasType),
                _DetailRow(
                    Icons.scale_outlined, 'Quantity', '${order.quantity} kg'),
                _DetailRow(Icons.attach_money_outlined, 'Total',
                    'KES ${order.totalAmount.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 32),
            if (isActive) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open Live Tracking'),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.liveTracking,
                  arguments: order.id,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 12),
              // Only show "Complete" once the rider has actually accepted
              if (order.status == OrderStatus.accepted ||
                  order.status == OrderStatus.inTransit)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: _isCompleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Complete Delivery'),
                  onPressed:
                      _isCompleting ? null : () => _deliverOrder(order.id),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
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
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 36)),
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
                  '${order.quantity} kg cylinder',
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
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
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
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
