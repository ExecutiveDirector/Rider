// lib/features/profile/screens/performance_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../data/repositories/profile_repository.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final _repo = ProfileRepository();
  bool _isLoading = true;

  // From /riders/analytics
  int totalDeliveries = 0;
  double rating = 0;
  double completionRate = 0;
  double acceptanceRate = 0;

  // From /riders/earnings
  double totalEarnings = 0;
  double thisWeek = 0;
  double thisMonth = 0;

  // Weekly bar chart data — 7 values
  List<double> weeklyDeliveries = List.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final analytics = await _repo.getAnalytics();
      final earnings = await _repo.getEarnings();

      if (mounted) {
        setState(() {
          totalDeliveries = analytics['total_deliveries'] ?? analytics['totalDeliveries'] ?? 0;
          rating = (analytics['rating'] ?? 0).toDouble();
          completionRate = (analytics['completion_rate'] ?? analytics['completionRate'] ?? 0).toDouble();
          acceptanceRate = (analytics['acceptance_rate'] ?? analytics['acceptanceRate'] ?? 0).toDouble();

          totalEarnings = (earnings['total'] ?? earnings['totalEarnings'] ?? 0).toDouble();
          thisWeek = (earnings['this_week'] ?? earnings['thisWeek'] ?? 0).toDouble();
          thisMonth = (earnings['this_month'] ?? earnings['thisMonth'] ?? 0).toDouble();

          // weekly_deliveries is an array of 7 numbers [Mon..Sun]
          final raw = analytics['weekly_deliveries'] ?? analytics['weeklyDeliveries'];
          if (raw is List && raw.length >= 7) {
            weeklyDeliveries = raw.take(7).map((v) => (v as num).toDouble()).toList();
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dioErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Performance'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _isLoading = true);
                await _load();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── KPI grid ──────────────────────────────────────────
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _KpiCard(
                          icon: Icons.local_shipping_outlined,
                          label: 'Total Deliveries',
                          value: '$totalDeliveries',
                          color: AppColors.primary,
                        ),
                        _KpiCard(
                          icon: Icons.star_rounded,
                          label: 'Rating',
                          value: rating.toStringAsFixed(1),
                          color: const Color(0xFFF59E0B),
                        ),
                        _KpiCard(
                          icon: Icons.check_circle_outline,
                          label: 'Completion Rate',
                          value: '${completionRate.toStringAsFixed(0)}%',
                          color: AppColors.success,
                        ),
                        _KpiCard(
                          icon: Icons.touch_app_outlined,
                          label: 'Acceptance Rate',
                          value: '${acceptanceRate.toStringAsFixed(0)}%',
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Earnings summary ──────────────────────────────────
                    _SectionHeader('Earnings'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _EarningsTile(
                              label: 'This Week',
                              amount: thisWeek),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _EarningsTile(
                              label: 'This Month',
                              amount: thisMonth),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _EarningsTile(
                              label: 'All Time',
                              amount: totalEarnings),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Weekly deliveries chart ───────────────────────────
                    _SectionHeader('This Week\'s Deliveries'),
                    const SizedBox(height: 12),
                    Container(
                      height: 180,
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: weeklyDeliveries.every((v) => v == 0)
                          ? const Center(
                              child: Text(
                                'No deliveries this week',
                                style: TextStyle(color: AppColors.textHint),
                              ),
                            )
                          : BarChart(
                              BarChartData(
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (v, _) {
                                        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                        return Text(
                                          days[v.toInt()],
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: weeklyDeliveries
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => BarChartGroupData(
                                        x: e.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: e.value,
                                            color: AppColors.primary,
                                            width: 22,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarningsTile extends StatelessWidget {
  final String label;
  final double amount;
  const _EarningsTile({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Text(
            'KES ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
