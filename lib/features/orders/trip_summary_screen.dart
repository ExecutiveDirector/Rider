// lib/features/orders/trip_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/shift_service.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/providers/earnings_provider.dart';
import '../../data/providers/growth_provider.dart';

/// Shown right after a delivery is confirmed. [earning] is null when the
/// backend doesn't send a rider fee; [cashToRemit] is the COD cash collected.
class TripSummaryScreen extends ConsumerStatefulWidget {
  final String orderNumber;
  final double? earning;
  final double cashToRemit;
  final bool paidByMpesa;
  const TripSummaryScreen({
    super.key,
    required this.orderNumber,
    this.earning,
    this.cashToRemit = 0,
    this.paidByMpesa = false,
  });

  @override
  ConsumerState<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends ConsumerState<TripSummaryScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh today's totals so the goal bar includes this trip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(earningsProvider.notifier).fetchSummary();
    });
    // The backend awards quest bonuses just after delivery; refresh once it has.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) ref.invalidate(questProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(earningsProvider).summary;
    final goal = ShiftService.instance.dailyGoal;
    final today = summary?.today ?? 0;
    final progress = (today / goal).clamp(0.0, 1.0).toDouble();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryLight, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      size: 48, color: AppColors.primaryDark),
                ),
                const SizedBox(height: 20),
                const Text('Delivery complete',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Order #${widget.orderNumber}',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                if (widget.earning != null)
                  Text('+ KES ${widget.earning!.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark)),
                if (widget.earning != null)
                  const Text('You earned',
                      style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                              child: Text("Today's goal",
                                  style: TextStyle(fontWeight: FontWeight.w700))),
                          Text(
                              'KES ${today.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: AppColors.primaryLight,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.paidByMpesa) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF064E3B)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Customer paid by M-Pesa — no cash to remit.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF064E3B))),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.cashToRemit > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            color: Color(0xFFB45309)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You collected KES ${widget.cashToRemit.toStringAsFixed(0)} cash. '
                            "It belongs to AquaGas — remit it from Earnings → Cash & payouts.",
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                GradientButton(
                  label: 'Back to orders',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
