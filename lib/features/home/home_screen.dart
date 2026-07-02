// lib/features/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
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
        onRefresh: () async {
          await ref.read(authProvider.notifier).loadProfile();
          await ref.read(orderProvider.notifier).fetchActiveOrders();
          await ref.read(earningsProvider.notifier).fetchSummary();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Show skeleton shimmer while profile loads
                                  auth.isLoading || driver == null
                                      ? _NameShimmer()
                                      : Text(
                                          'Hi, ${driver.name.split(' ').first} 👋',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOnline
                                        ? "You're online"
                                        : "You're offline",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _onToggleOnline,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? AppColors.accent
                                        : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isOnline
                                              ? Colors.white
                                              : Colors.white70,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isOnline ? 'Online' : 'Offline',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
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
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
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
                    _OfflineBanner()
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
                    _ErrorCard(
                      message: orderState.error!,
                      onRetry: () =>
                          ref.read(orderProvider.notifier).fetchActiveOrders(),
                    )
                  else if (orderState.activeOrders.isEmpty)
                    _EmptyOrdersCard()
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
        selectedIndex: 0,
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
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined), label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Earnings'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
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
          child: _StatCard(
            label: "Today's Earnings",
            value: 'KES ${summary?.today.toStringAsFixed(0) ?? '0'}',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Active Orders',
            value: '${orderState.activeOrders.length}',
            icon: Icons.local_shipping_outlined,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
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
      case OrderStatus.accepted:
        return AppColors.primary;
      case OrderStatus.inTransit:
        return const Color(0xFF722ED1);
      case OrderStatus.delivered:
        return AppColors.success;
      default:
        return AppColors.warning;
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
            // Status badge instead of amount
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                order.status.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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

// ─── Empty / error / offline banners ─────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.textHint.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('You\'re offline',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary)),
          SizedBox(height: 4),
          Text('Go online to start receiving orders',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyOrdersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          Text('📦', style: TextStyle(fontSize: 44)),
          SizedBox(height: 12),
          Text('No active orders',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary)),
          SizedBox(height: 4),
          Text('New orders will appear here',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 36, color: AppColors.error),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
