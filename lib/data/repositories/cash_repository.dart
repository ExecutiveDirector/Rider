// lib/data/repositories/cash_repository.dart
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../models/cash_models.dart';

class CashRepository {
  final _api = ApiService.instance;

  /// The rider's COD cash position. Returns null when the backend doesn't
  /// offer cash tracking (404/501) so the UI can say so instead of failing.
  Future<CashSummary?> getSummary() async {
    try {
      final res = await _api.get(ApiConstants.cashSummary);
      final body = res.data;
      if (body is! Map) return null;
      final data = body['data'] ?? body['summary'] ?? body;
      return CashSummary.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 501) return null;
      rethrow;
    }
  }

  /// Tell AquaGas the rider has paid [amount] of collected cash in via M-Pesa,
  /// quoting the M-Pesa confirmation code so finance can match it.
  Future<void> remitCash({
    required double amount,
    required String mpesaCode,
  }) async {
    await _api.post(ApiConstants.cashRemit, data: {
      'amount': amount,
      'mpesa_code': mpesaCode,
    });
  }

  Future<List<PayoutModel>> getPayouts() async {
    try {
      final res = await _api.get(ApiConstants.payouts);
      final body = res.data;
      final List data = body is Map
          ? (body['payouts'] as List? ?? body['data'] as List? ?? [])
          : (body as List? ?? []);
      return data
          .whereType<Map>()
          .map((e) => PayoutModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 501) return [];
      rethrow;
    }
  }

  /// Ask for [amount] of earned money to be sent to the rider's M-Pesa.
  Future<void> requestPayout(double amount) async {
    await _api.post(ApiConstants.payoutRequest, data: {'amount': amount});
  }
}
