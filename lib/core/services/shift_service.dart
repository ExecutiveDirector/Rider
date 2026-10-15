// lib/core/services/shift_service.dart
import 'storage_service.dart';

/// Daily earnings goal and the current online session start. Local only
/// (Hive prefs) — a rider's personal target, not business data.
class ShiftService {
  ShiftService._();
  static final ShiftService instance = ShiftService._();

  static const _goalKey = 'daily_goal_kes';
  static const _sinceKey = 'online_since_iso';
  static const double defaultGoal = 2000;

  double get dailyGoal {
    final raw = StorageService.instance.getString(_goalKey);
    final v = raw == null ? null : double.tryParse(raw);
    return (v != null && v > 0) ? v : defaultGoal;
  }

  Future<void> setDailyGoal(double kes) =>
      StorageService.instance.setString(_goalKey, kes.round().toString());

  DateTime? get onlineSince {
    final raw = StorageService.instance.getString(_sinceKey);
    return raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  Future<void> markOnline() async {
    // Keep the original start if the app was restarted mid-shift.
    if (onlineSince == null) {
      await StorageService.instance
          .setString(_sinceKey, DateTime.now().toIso8601String());
    }
  }

  Future<void> markOffline() =>
      StorageService.instance.setString(_sinceKey, '');
}
