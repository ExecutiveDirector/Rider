// lib/features/orders/completed_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/routes.dart';
import '../../data/providers/order_provider.dart';
import '../../data/models/order_model.dart';

class CompletedOrdersScreen extends ConsumerStatefulWidget {
  const CompletedOrdersScreen({super.key});

  @override
  ConsumerState<CompletedOrdersScreen> createState() =>
      _CompletedOrdersScreenState();
}

class _CompletedOrdersScreenState
    extends ConsumerState<CompletedOrdersScreen> {
  final _scrollController = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderProvider.notifier).fetchCompletedOrders(page: 1);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        _hasMore &&
        !_isFetchingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isFetchingMore = true);
    final prevCount = ref.read(orderProvider).completedOrders.length;
    _page++;
    await ref
        .read(orderProvider.notifier)
        .fetchCompletedOrders(page: _page);
    final newCount = ref.read(orderProvider).completedOrders.length;
    // If count didn't grow by at least 1, we've reached the end
    if (newCount == prevCount) {
      setState(() => _hasMore = false);
    }
    if (mounted) setState(() => _isFetchingMore = false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider);
    final orders = state.completedOrders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Completed Orders'),
        centerTitle: true,
      ),
      body: state.isLoading && orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    _page = 1;
                    _hasMore = true;
                    await ref
                        .read(orderProvider.notifier)
                        .fetchCompletedOrders(page: 1);
                  },
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: orders.length + (_isFetchingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      if (i == orders.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return _CompletedOrderCard(order: orders[i]);
                    },
                  ),
                ),
    );
  }
}

class _CompletedOrderCard extends StatelessWidget {
  final OrderModel order;
  const _CompletedOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.orderDetails,
        arguments: order.id,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${order.orderNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.deliveryAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KES ${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(order.createdAt),
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    return DateFormat('d MMM').format(dt);
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 40,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No completed orders yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your delivery history will appear here',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
