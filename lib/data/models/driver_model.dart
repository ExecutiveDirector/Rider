// lib/data/models/driver_model.dart

class DriverModel {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final String? vehicleType;
  final String? vehiclePlate;
  final bool isOnline;
  final bool isVerified;
  final double rating;
  final int totalDeliveries;

  const DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.vehicleType,
    this.vehiclePlate,
    this.isOnline = false,
    this.isVerified = false,
    this.rating = 0.0,
    this.totalDeliveries = 0,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    // Backend alias fixed: 'auth_account' → 'account'. Support both during deploy.
    final account = json['account'] as Map<String, dynamic>? ??
        json['auth_account'] as Map<String, dynamic>?;

    // Name: login response sends flat 'name'; profile endpoint sends
    // 'first_name' + 'last_name' from the riders table.
    final String name = json['name'] as String? ??
        '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim();

    // ID: login sends rider.id (= rider_id); profile sends rider_id directly.
    final int id = _asInt(json['id'] ?? json['rider_id']);

    // Phone: prefer E.164 number from auth_accounts, fall back to riders.phone.
    final String phone = account?['phone_number'] as String? ??
        json['phone_number'] as String? ??
        json['phone'] as String? ??
        '';

    // Email: lives in auth_accounts. Login inlines it as 'email';
    // profile endpoint nests it under the account association.
    final String? email =
        json['email'] as String? ?? account?['email'] as String?;

    return DriverModel(
      id: id,
      name: name,
      phone: phone,
      email: email,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      vehicleType:
          json['vehicleType'] as String? ?? json['vehicle_type'] as String?,
      vehiclePlate: json['vehiclePlate'] as String? ??
          json['vehicle_plate'] as String? ??
          json['vehicle_registration'] as String?,
      isOnline: _asBool(json['isOnline'] ?? json['is_online']),
      isVerified: _asBool(json['isVerified'] ?? json['is_verified']),
      // MySQL DECIMAL arrives as a string ("4.50"); a hard cast threw and
      // silently dropped the whole profile, leaving a signed-in rider with no data.
      rating: _asDouble(json['rating']),
      totalDeliveries: _asInt(json['totalDeliveries'] ?? json['total_deliveries']),
    );
  }

  static bool _asBool(Object? v) =>
      v is bool ? v : (v is num ? v != 0 : '${v ?? ''}' == 'true' || '${v ?? ''}' == '1');

  static int _asInt(Object? v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  static double _asDouble(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'avatarUrl': avatarUrl,
        'vehicleType': vehicleType,
        'vehiclePlate': vehiclePlate,
        'isOnline': isOnline,
        'isVerified': isVerified,
        'rating': rating,
        'totalDeliveries': totalDeliveries,
      };

  DriverModel copyWith({bool? isOnline}) {
    return DriverModel(
      id: id,
      name: name,
      phone: phone,
      email: email,
      avatarUrl: avatarUrl,
      vehicleType: vehicleType,
      vehiclePlate: vehiclePlate,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified,
      rating: rating,
      totalDeliveries: totalDeliveries,
    );
  }
}
