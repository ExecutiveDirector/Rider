// lib/data/repositories/growth_repository.dart
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../models/growth_models.dart';

class GrowthRepository {
  final _api = ApiService.instance;

  Map<String, dynamic> _data(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  Future<QuestProgress> getQuests() async {
    final res = await _api.get(ApiConstants.incentives);
    return QuestProgress.fromJson(_data(res.data));
  }

  Future<List<DemandZone>> getDemandZones({int hours = 3}) async {
    final res =
        await _api.get(ApiConstants.demandZones, params: {'hours': hours});
    final zones = (_data(res.data)['zones'] as List?) ?? [];
    return zones
        .map((e) => DemandZone.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
