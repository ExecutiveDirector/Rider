// lib/data/providers/earnings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/earnings_model.dart';
import '../repositories/earnings_repository.dart';

final earningsRepositoryProvider = Provider((_) => EarningsRepository());

class EarningsState {
  final EarningsSummary? summary;
  final List<EarningsModel> earnings;
  final String period; // 'today' | 'week' | 'month'
  final bool isLoading;
  final String? error;

  const EarningsState({
    this.summary,
    this.earnings = const [],
    this.period = 'week',
    this.isLoading = false,
    this.error,
  });

  EarningsState copyWith({
    EarningsSummary? summary,
    List<EarningsModel>? earnings,
    String? period,
    bool? isLoading,
    String? error,
  }) {
    return EarningsState(
      summary: summary ?? this.summary,
      earnings: earnings ?? this.earnings,
      period: period ?? this.period,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EarningsNotifier extends StateNotifier<EarningsState> {
  final EarningsRepository _repo;
  EarningsNotifier(this._repo) : super(const EarningsState());

  Future<void> fetchSummary() async {
    state = state.copyWith(isLoading: true);
    try {
      final summary = await _repo.getSummary();
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchEarnings(String period) async {
    state = state.copyWith(isLoading: true, period: period);
    try {
      final earnings = await _repo.getEarnings(period: period);
      state = state.copyWith(earnings: earnings, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final earningsProvider = StateNotifierProvider<EarningsNotifier, EarningsState>(
  (ref) => EarningsNotifier(ref.read(earningsRepositoryProvider)),
);
