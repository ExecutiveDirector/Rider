// lib/features/home/widgets/quest_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/providers/growth_provider.dart';

/// "Do 5 deliveries today, earn KES 100 extra" — progress to the next bonus tier.
/// Hidden when the endpoint is unavailable so an older backend never shows an error.
class QuestCard extends ConsumerWidget {
  const QuestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questProvider);
    return quest.maybeWhen(
      data: (q) {
        if (q.tiers.isEmpty) return const SizedBox.shrink();
        final allDone = q.nextTarget == null;
        final target = allDone ? q.tiers.last.target : q.nextTarget!;
        final progress =
            (q.deliveriesToday / target).clamp(0.0, 1.0).toDouble();
        return Container(
          margin: const EdgeInsets.only(top: 12),
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
                  const Icon(Icons.emoji_events_outlined,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      allDone
                          ? 'All bonuses unlocked 🎉'
                          : 'Deliver ${q.remaining} more, earn KES ${q.nextBonus!.round()}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  if (q.bonusEarnedToday > 0)
                    Text('+KES ${q.bonusEarnedToday.round()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.primaryLight,
                  valueColor: AlwaysStoppedAnimation(
                      allDone ? AppColors.success : AppColors.accent),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final t in q.tiers)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                          t.reached ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: t.reached
                              ? AppColors.success
                              : AppColors.textSecondary),
                      label: Text('${t.target} → KES ${t.bonus.round()}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              Text('${q.deliveriesToday} delivered today',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
