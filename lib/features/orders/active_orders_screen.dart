// lib/features/orders/active_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/config/routes.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/order_provider.dart';

class ActiveOrdersScreen extends ConsumerStatefulWidget {
  const ActiveOrdersScreen({super.key});

  @override
  ConsumerState<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends ConsumerState<ActiveOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  Future<void> _loadOrders() async {
    await ref.read(orderProvider.notifier).fetchActiveOrders();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        title: Text('Active Orders (${state.activeOrders.length})'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(OrderState state) {
    if (state.isLoading && state.activeOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.activeOrders.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 140),
          const Icon(Icons.error_outline_rounded, size: 72, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(state.error!, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (state.activeOrders.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 160),
          Center(
            child: Column(
              children: [
                Text('📦', style: TextStyle(fontSize: 64)),
                SizedBox(height: 16),
                Text('No Active Orders',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('Orders assigned to you will appear here',
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.activeOrders.length,
      itemBuilder: (_, index) {
        final order = state.activeOrders[index];
        return OrderCard(
          key: ValueKey(order.id),
          order: order,
          onTap: () async {
            await Navigator.pushNamed(
              context,
              AppRoutes.orderDetails,
              arguments: order.id,
            );
            if (mounted) _loadOrders();
          },
        );
      },
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class OrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  ConsumerState<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<OrderCard> {
  bool _busy = false;

  static Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.accepted:
        return AppColors.primary;
      case OrderStatus.inTransit:
        return const Color(0xFF722ED1);
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  // Returns null when no action button should show (delivered / cancelled).
  _Btn? _buttonFor(OrderStatus status) {
    switch (status) {
      case OrderStatus.accepted:
        // DB status is 'dispatched' — rider needs to physically collect from vendor
        return const _Btn(
          label: 'Confirm Pickup',
          icon: Icons.storefront_outlined,
          color: Color(0xFF722ED1),
          confirmBody:
              'Confirm you have collected the gas cylinder from the vendor outlet.',
        );
      case OrderStatus.inTransit:
        // DB status is 'ready' — rider collected, now heading to customer
        return const _Btn(
          label: 'Mark Delivered',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          confirmBody:
              'Confirm the gas cylinder has been delivered to the customer.',
        );
      default:
        return null;
    }
  }

  Future<void> _onAction(_Btn btn) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(btn.label),
        content: Text(btn.confirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: btn.color),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    setState(() => _busy = true);

    final notifier = ref.read(orderProvider.notifier);
    final success = widget.order.status == OrderStatus.accepted
        ? await notifier.pickupOrder(widget.order.id)
        : await notifier.deliverOrder(widget.order.id);

    if (mounted) {
      setState(() => _busy = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update order. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final color = _statusColor(order.status);
    final btn = _buttonFor(order.status);

    final shortId = order.orderNumber.isNotEmpty
        ? order.orderNumber.toUpperCase()
        : order.id.toUpperCase();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Status bar
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text('Order #$shortId',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                      _Badge(label: order.status.label, color: color),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _InfoRow(
                      icon: Icons.person_outline, value: order.customerName),
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.location_on_outlined,
                      value: order.deliveryAddress),
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.local_fire_department_outlined,
                      value:
                          '${order.quantity.toStringAsFixed(0)}kg ${order.gasType}'),
                  const SizedBox(height: 16),

                  // Amount + action row
                  Row(
                    children: [
                      Text(
                        'KES ${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (btn != null)
                        _ActionButton(
                            btn: btn, busy: _busy, onTap: () => _onAction(btn))
                      else
                        _ViewChip(onTap: widget.onTap),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class _ActionButton extends StatelessWidget {
  final _Btn btn;
  final bool busy;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.btn, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: btn.color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(btn.icon, size: 18),
        label: Text(busy ? 'Updating…' : btn.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class _ViewChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewChip({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Text('View Details',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
            ],
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
        ],
      );
}

// ─── Value object ─────────────────────────────────────────────────────────────

class _Btn {
  final String label;
  final IconData icon;
  final Color color;
  final String confirmBody;
  const _Btn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.confirmBody});
}
