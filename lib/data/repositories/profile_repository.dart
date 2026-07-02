// lib/features/profile/repositories/profile_repository.dart

import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../models/rider_profile.dart';

class ProfileRepository {
  final ApiService _api = ApiService.instance;

  Future<RiderProfile> getProfile() async {
    final response = await _api.get(
      ApiConstants.profile,
    );

    return RiderProfile.fromJson(response.data);
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    String? nationalId,
  }) async {
    await _api.put(
      ApiConstants.profile,
      data: {
        "name": name,
        "phone_number": phone,
        "national_id": nationalId,
      },
    );
  }

  Future<void> updateEmergency({
    required String name,
    required String phone,
  }) async {
    await _api.put(
      ApiConstants.profile,
      data: {
        "emergency_contact_name": name,
        "emergency_contact_phone": phone,
      },
    );
  }

  Future<void> updateVehicle({
    required String vehicleType,
    required String registration,
  }) async {
    await _api.put(
      ApiConstants.profile,
      data: {
        "vehicle_type": vehicleType,
        "vehicle_registration": registration,
      },
    );
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final response = await _api.get(
      '/riders/analytics',
    );

    return response.data;
  }

  Future<Map<String, dynamic>> getRatings() async {
    final response = await _api.get(
      '/riders/ratings',
    );

    return response.data;
  }

  Future<Map<String, dynamic>> getEarnings() async {
    final response = await _api.get(
      '/riders/earnings',
    );

    return response.data;
  }
}
