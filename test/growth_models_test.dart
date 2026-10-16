import 'package:flutter_test/flutter_test.dart';
import 'package:aquagas_rider/data/models/growth_models.dart';

void main() {
  test('QuestProgress parses next tier', () {
    final q = QuestProgress.fromJson({
      'deliveries_today': 7,
      'bonus_earned_today': 100,
      'tiers': [
        {'target': 5, 'bonus': 100, 'reached': true},
        {'target': 10, 'bonus': 250, 'reached': false},
      ],
      'next': {'target': 10, 'bonus': 250, 'remaining': 3},
    });
    expect(q.remaining, 3);
    expect(q.tiers.first.reached, isTrue);
    expect(q.nextBonus, 250);
  });

  test('QuestProgress with all tiers done has no next', () {
    final q = QuestProgress.fromJson(
        {'deliveries_today': 20, 'tiers': [], 'next': null});
    expect(q.nextTarget, isNull);
  });

  test('DemandZone clamps intensity and defaults radius', () {
    final z = DemandZone.fromJson(
        {'latitude': -1.28, 'longitude': 36.82, 'count': 4, 'intensity': 3});
    expect(z.intensity, 1.0);
    expect(z.radiusM, 550);
  });
}
