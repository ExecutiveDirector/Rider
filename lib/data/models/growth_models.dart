// lib/data/models/growth_models.dart
// Daily quests (GET /riders/incentives) and demand zones (GET /riders/demand-zones).

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class QuestTier {
  final int target;
  final double bonus;
  final bool reached;
  const QuestTier(
      {required this.target, required this.bonus, required this.reached});

  factory QuestTier.fromJson(Map<String, dynamic> j) => QuestTier(
        target: _i(j['target']),
        bonus: _d(j['bonus']),
        reached: j['reached'] == true,
      );
}

class QuestProgress {
  final int deliveriesToday;
  final List<QuestTier> tiers;
  final double bonusEarnedToday;
  final int? nextTarget;
  final double? nextBonus;
  final int? remaining;

  const QuestProgress({
    required this.deliveriesToday,
    required this.tiers,
    required this.bonusEarnedToday,
    this.nextTarget,
    this.nextBonus,
    this.remaining,
  });

  factory QuestProgress.fromJson(Map<String, dynamic> j) {
    final next = j['next'] is Map ? Map<String, dynamic>.from(j['next']) : null;
    return QuestProgress(
      deliveriesToday: _i(j['deliveries_today']),
      tiers: ((j['tiers'] as List?) ?? [])
          .map((e) => QuestTier.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bonusEarnedToday: _d(j['bonus_earned_today']),
      nextTarget: next == null ? null : _i(next['target']),
      nextBonus: next == null ? null : _d(next['bonus']),
      remaining: next == null ? null : _i(next['remaining']),
    );
  }
}

class DemandZone {
  final double latitude;
  final double longitude;
  final int count;
  final double intensity; // 0..1, busiest zone = 1
  final double radiusM;
  const DemandZone({
    required this.latitude,
    required this.longitude,
    required this.count,
    required this.intensity,
    required this.radiusM,
  });

  factory DemandZone.fromJson(Map<String, dynamic> j) => DemandZone(
        latitude: _d(j['latitude']),
        longitude: _d(j['longitude']),
        count: _i(j['count']),
        intensity: _d(j['intensity']).clamp(0.0, 1.0).toDouble(),
        radiusM: _d(j['radius_m']) > 0 ? _d(j['radius_m']) : 550,
      );
}
