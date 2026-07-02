class RiderProfile {
  final String name;
  final String email;
  final String phone;
  final String vehicleType;
  final String vehicleRegistration;
  final String? nationalId;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final bool isVerified;
  final String status;
  final double rating;
  final int totalDeliveries;

  RiderProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.vehicleType,
    required this.vehicleRegistration,
    this.nationalId,
    this.emergencyContactName,
    this.emergencyContactPhone,
    required this.isVerified,
    required this.status,
    required this.rating,
    required this.totalDeliveries,
  });

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    // Backend wraps the rider row under a 'data' key
    final data = json['data'] as Map<String, dynamic>? ?? json;

    // The auth_accounts association alias was fixed from 'auth_account' → 'account'
    // Support both so the app keeps working during/after the backend deploy.
    final account = data['account'] as Map<String, dynamic>? ??
        data['auth_account'] as Map<String, dynamic>?;

    // Phone: prefer the E.164 number on auth_accounts, fall back to riders.phone
    final phone =
        account?['phone_number'] as String? ?? data['phone'] as String? ?? '';

    return RiderProfile(
      name: '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
      email: account?['email'] as String? ?? '',
      phone: phone,
      vehicleType: data['vehicle_type'] as String? ?? '',
      vehicleRegistration: data['vehicle_registration'] as String? ?? '',
      nationalId: data['national_id'] as String?,
      emergencyContactName: data['emergency_contact_name'] as String?,
      emergencyContactPhone: data['emergency_contact_phone'] as String?,
      isVerified: data['is_verified'] as bool? ?? false,
      status: data['current_status'] as String? ?? 'offline',
      rating: double.tryParse('${data['rating'] ?? 0}') ?? 0.0,
      totalDeliveries: data['total_deliveries'] as int? ?? 0,
    );
  }
}
