// lib/data/repositories/earnings_repository.dart
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../models/earnings_model.dart';

class EarningsRepository {
  final _api = ApiService.instance;

  Future<EarningsSummary> getSummary() async {
    // The /riders/earnings/summary endpoint returns 404 until it's built.
    // Return zeroed summary so the home screen doesn't crash.
    try {
      final response = await _api.get(ApiConstants.earningsSummary);
      return EarningsSummary.fromJson(
          response.data['summary'] ?? response.data);
    } catch (_) {
      return EarningsSummary.empty();
    }
  }

  Future<List<EarningsModel>> getEarnings({
    required String period, // 'today' | 'week' | 'month'
    int page = 1,
  }) async {
    try {
      final response = await _api.get(
        ApiConstants.earnings,
        params: {'period': period, 'page': page, 'limit': 20},
      );
      final List data = response.data['earnings'] ?? response.data ?? [];
      return data.map((e) => EarningsModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
