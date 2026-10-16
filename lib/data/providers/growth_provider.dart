// lib/data/providers/growth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/growth_models.dart';
import '../repositories/growth_repository.dart';

final growthRepositoryProvider = Provider((_) => GrowthRepository());

/// Today's quest progress. Invalidate after a delivery to refresh.
final questProvider = FutureProvider.autoDispose<QuestProgress>(
    (ref) => ref.read(growthRepositoryProvider).getQuests());

final demandZonesProvider = FutureProvider.autoDispose<List<DemandZone>>(
    (ref) => ref.read(growthRepositoryProvider).getDemandZones());
