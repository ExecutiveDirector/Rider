// lib/features/earnings/earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/providers/earnings_provider.dart';
import '../../data/models/earnings_model.dart';
import 'package:intl/intl.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  final _periods = ['today', 'week', 'month'];
  int _selectedPeriod = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(earningsProvider.notifier).fetchSummary();
      ref.read(earningsProvider.notifier).fetchEarnings('week');
    });
  }

  void _onPeriodChanged(int index) {
    setState(() => _selectedPeriod = index);
    ref.read(earningsProvider.notifier).fetchEarnings(_periods[index]);
  }

  String _periodLabel(int i) {
    switch (i) {
      case 0: return 'Today';
      case 1: return 'This Week';
      case 2: return 'This Month';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(earningsProvider);
    final summary = state.summary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(earningsProvider.notifier).fetchSummary();
          await ref
              .read(earningsProvider.notifier)
              .fetchEarnings(_periods[_selectedPeriod]);
        },
        child: CustomScrollView(
          slivers: [
            // Summary banner
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Earnings',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'KES ${(summary?.thisMonth ?? 0).toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This month',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _MiniStat(
                          label: 'Today',
                          value: 'KES ${(summary?.today ?? 0).toStringAsFixed(0)}',
                        ),
                        const SizedBox(width: 24),
                        _MiniStat(
                          label: 'This Week',
                          value: 'KES ${(summary?.thisWeek ?? 0).toStringAsFixed(0)}',
                        ),
                        const SizedBox(width: 24),
                        _MiniStat(
                          label: 'Pending',
                          value: 'KES ${(summary?.pendingPayout ?? 0).toStringAsFixed(0)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Deliveries stat row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _DeliveryStatCard(
                        value: summary?.totalDeliveriesToday ?? 0,
                        label: 'Today',
                        icon: Icons.today_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DeliveryStatCard(
                        value: summary?.totalDeliveriesWeek ?? 0,
                        label: 'This Week',
                        icon: Icons.date_range_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DeliveryStatCard(
                        value: summary?.totalDeliveriesMonth ?? 0,
                        label: 'This Month',
                        icon: Icons.calendar_month_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Period selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: GestureDetector(
                        onTap: () => _onPeriodChanged(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedPeriod == i
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedPeriod == i
                                  ? AppColors.primary
                                  : AppColors.divider,
                            ),
                          ),
                          child: Text(
                            _periodLabel(i),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _selectedPeriod == i
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Earnings list
            if (state.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (state.earnings.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'No earnings for this period',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _EarningsItem(earning: state.earnings[i]),
                    childCount: state.earnings.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

class _DeliveryStatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  const _DeliveryStatCard(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _EarningsItem extends StatelessWidget {
  final EarningsModel earning;
  const _EarningsItem({required this.earning});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, h:mm a').format(earning.date);
    final isPaid = earning.status == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${earning.orderId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'KES ${earning.netAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPaid ? AppColors.success : AppColors.warning)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isPaid ? 'Paid' : 'Pending',
                  style: TextStyle(
                    color: isPaid ? AppColors.success : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
