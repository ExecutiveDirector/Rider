// lib/features/home/widgets/goal_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/shift_service.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/earnings_provider.dart';

/// Today's goal progress, deliveries and time online — the "am I on track?"
/// glance drivers get in Bolt/Uber. Tap the pencil to change the goal.
class GoalCard extends ConsumerStatefulWidget {
  const GoalCard({super.key});

  @override
  ConsumerState<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<GoalCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _onlineLabel(bool online) {
    final since = ShiftService.instance.onlineSince;
    if (!online || since == null) return '—';
    final d = DateTime.now().difference(since);
    if (d.inMinutes < 1) return '<1m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Future<void> _editGoal() async {
    final ctrl = TextEditingController(
        text: ShiftService.instance.dailyGoal.round().toString());
    final saved = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily earnings goal'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: 'KES '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              Navigator.pop(ctx, (v != null && v >= 100) ? v : null);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved != null) {
      await ShiftService.instance.setDailyGoal(saved);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(earningsProvider).summary;
    final online = ref.watch(authProvider).driver?.isOnline ?? false;
    final goal = ShiftService.instance.dailyGoal;
    final today = summary?.today ?? 0;
    final progress = (today / goal).clamp(0.0, 1.0).toDouble();
    final reached = today >= goal;

    return Container(
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
              Expanded(
                child: Text(
                  reached ? 'Goal reached 🎉' : "Today's goal",
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                ),
              ),
              Text(
                'KES ${today.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.primaryDark),
              ),
              IconButton(
                tooltip: 'Change goal',
                visualDensity: VisualDensity.compact,
                onPressed: _editGoal,
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.primaryLight,
              valueColor: AlwaysStoppedAnimation(
                  reached ? AppColors.success : AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Mini(
                  icon: Icons.local_shipping_outlined,
                  label: 'Deliveries',
                  value: '${summary?.totalDeliveriesToday ?? 0}'),
              _Mini(
                  icon: Icons.timer_outlined,
                  label: 'Online',
                  value: _onlineLabel(online)),
              _Mini(
                  icon: Icons.trending_up,
                  label: 'Left to goal',
                  value: reached
                      ? '—'
                      : 'KES ${(goal - today).toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Mini({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: AppColors.textPrimary)),
                Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
