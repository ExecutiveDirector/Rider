// lib/features/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/pulse_dot.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/stat_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/config/routes.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/location_service.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/earnings_provider.dart';
import '../../data/models/order_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load profile if not already in state (cold start / session restore)
      if (ref.read(authProvider).driver == null) {
        ref.read(authProvider.notifier).loadProfile();
      }
      ref.read(orderProvider.notifier).fetchActiveOrders();
      ref.read(earningsProvider.notifier).fetchSummary();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.read(orderProvider.notifier).fetchActiveOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onToggleOnline() async {
    final driver = ref.read(authProvider).driver;
    if (driver == null) return;

    final isCurrentlyOnline = driver.isOnline;
    ref.read(authProvider.notifier).toggleOnlineStatus();

    if (!isCurrentlyOnline) {
      final hasPermission = await LocationService.instance.requestPermissions();
      if (hasPermission) {
        SocketService.instance.connect();
        SocketService.instance.registerDriver(driver.id);
      }
    } else {
      SocketService.instance.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final orderState = ref.watch(orderProvider);
    final driver = auth.driver;
    final isOnline = driver?.isOnline ?? false;

    // NOTE: the incoming-order sheet listener now lives in app.dart at the
    // root of the widget tree, so it fires regardless of which screen is
    // currently showing (was previously scoped to this screen only).

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(authProvider.notifier).loadProfile();
          await ref.read(orderProvider.notifier).fetchActiveOrders();
          await ref.read(earningsProvider.notifier).fetchSummary();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 176,
              pinned: true,
              backgroundColor: AppColors.primaryDark,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -40,
                        right: -30,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.accentMint.withOpacity(0.28),
                                AppColors.accentMint.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Show skeleton shimmer while profile loads
                                        auth.isLoading || driver == null
                                            ? _NameShimmer()
                                            : Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      'Hi, ${driver.name.split(' ').first} 👋',
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  if (driver.rating > 0) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 7, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.18),
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.star_rounded,
                                                              color: Color(0xFFFBBF24), size: 13),
                                                          const SizedBox(width: 2),
                                                          Text(
                                                            driver.rating.toStringAsFixed(1),
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 11.5,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                        const SizedBox(height: 3),
                                        Text(
                                          isOnline
                                              ? "You're online and visible to dispatch"
                                              : "You're offline",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: _onToggleOnline,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: isOnline ? AppColors.brightGradient : null,
                                        color: isOnline ? null : Colors.white.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(24),
                                        border: isOnline
                                            ? null
                                            : Border.all(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isOnline)
                                            const PulseDot(color: Colors.white, size: 7)
                                          else
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: Colors.white70,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isOnline ? 'Online' : 'Offline',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (!orderState.isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Pull down to refresh',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ),
                  _StatsRow(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Active Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (orderState.activeOrders.isNotEmpty)
                        TextButton(
                          onPressed: () => Navigator.pushNamed(
                              context, AppRoutes.activeOrders),
                          child: const Text('See all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!isOnline)
                    AppEmptyState(
                      icon: Icons.wifi_tethering_off_rounded,
                      title: "You're offline",
                      message: 'Go online to start receiving orders',
                      iconColor: AppColors.textHint,
                      compact: true,
                    )
                  else if (orderState.isLoading &&
                      orderState.activeOrders.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (orderState.error != null &&
                      orderState.activeOrders.isEmpty)
                    AppEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load orders',
                      message: orderState.error!,
                      iconColor: AppColors.error,
                      actionLabel: 'Retry',
                      onAction: () =>
                          ref.read(orderProvider.notifier).fetchActiveOrders(),
                      compact: true,
                    )
                  else if (orderState.activeOrders.isEmpty)
                    AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No active orders',
                      message: 'New orders will appear here',
                      compact: true,
                    )
                  else
                    ...orderState.activeOrders.take(3).map((order) {
                      if (order.status == OrderStatus.pending) {
                        return _PendingOrderCard(order: order);
                      }
                      return _ActiveOrderTile(
                        order: order,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.orderDetails,
                          arguments: order.id,
                        ),
                      );
                    }),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 1:
              Navigator.pushNamed(context, AppRoutes.activeOrders);
              break;
            case 2:
              Navigator.pushNamed(context, AppRoutes.earnings);
              break;
            case 3:
              Navigator.pushNamed(context, AppRoutes.profile);
              break;
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Earnings'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}

// ─── Skeleton shimmer for name while profile loads ────────────────────────────

class _NameShimmer extends StatefulWidget {
  @override
  State<_NameShimmer> createState() => _NameShimmerState();
}

class _NameShimmerState extends State<_NameShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 140,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_anim.value),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(earningsProvider).summary;
    final orderState = ref.watch(orderProvider);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.earnings),
            child: StatTile(
              label: "Today's Earnings",
              value: 'KES ${summary?.today.toStringAsFixed(0) ?? '0'}',
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.activeOrders),
            child: StatTile(
              label: 'Active Orders',
              value: '${orderState.activeOrders.length}',
              icon: Icons.local_shipping_outlined,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Active order tile — status badge instead of amount ──────────────────────

class _ActiveOrderTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _ActiveOrderTile({required this.order, required this.onTap});

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return AppColors.pending;
      case OrderStatus.accepted:
        return AppColors.accepted;
      case OrderStatus.inTransit:
        return AppColors.inTransit;
      case OrderStatus.delivered:
        return AppColors.delivered;
      case OrderStatus.cancelled:
        return AppColors.cancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_fire_department_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(order.deliveryAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(label: order.status.label, color: color, dense: true),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Pending order card (accept / decline) ────────────────────────────────────

class _PendingOrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  const _PendingOrderCard({required this.order});

  @override
  ConsumerState<_PendingOrderCard> createState() => _PendingOrderCardState();
}

class _PendingOrderCardState extends ConsumerState<_PendingOrderCard> {
  bool _isAccepting = false;
  bool _isDeclining = false;

  Future<void> _accept() async {
    setState(() => _isAccepting = true);
    final success =
        await ref.read(orderProvider.notifier).acceptOrder(widget.order.id);
    if (mounted) {
      setState(() => _isAccepting = false);
      if (success) {
        Navigator.pushNamed(context, AppRoutes.orderDetails,
            arguments: widget.order.id);
      }
    }
  }

  Future<void> _decline() async {
    setState(() => _isDeclining = true);
    await ref.read(orderProvider.notifier).rejectOrder(
          widget.order.id,
          reason: 'Rider declined',
        );
    if (mounted) setState(() => _isDeclining = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_fire_department_outlined,
                        color: AppColors.warning, size: 22),
                  ),
                  Positioned(
                    top: -3,
                    right: -3,
                    child: PulseDot(color: AppColors.warning, size: 8),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.order.customerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(widget.order.deliveryAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              // Amount shown here only since this is the accept/decline decision moment
              Text(
                'KES ${widget.order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_isAccepting || _isDeclining) ? null : _decline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: _isDeclining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.error))
                      : const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_isAccepting || _isDeclining) ? null : _accept,
                  child: _isAccepting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
