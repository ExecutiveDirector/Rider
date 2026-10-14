// lib/core/utils/json_utils.dart
//
// Tolerant JSON readers. Sequelize returns MySQL DECIMAL columns as strings
// ("250.00"), so a bare `(x as num)` or `x.toDouble()` throws on real data.

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

double asDoubleOr(dynamic v, [double fallback = 0]) => asDouble(v) ?? fallback;

int asIntOr(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

bool asBool(dynamic v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return fallback;
}

Map<String, dynamic>? asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// First [max] characters of an id. Order ids can be short numeric strings,
/// so `id.substring(0, 8)` would throw a RangeError.
String shortId(String id, [int max = 8]) =>
    id.length <= max ? id : id.substring(0, max);
