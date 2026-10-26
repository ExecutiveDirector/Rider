// lib/data/providers/cash_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../models/cash_models.dart';
import '../repositories/cash_repository.dart';

final cashRepositoryProvider = Provider((_) => CashRepository());

class CashState {
  final CashSummary? summary;
  final List<PayoutModel> payouts;
  final bool isLoading;

  /// The backend has no cash-tracking endpoint (yet).
  final bool unavailable;
  final String? error;

  const CashState({
    this.summary,
    this.payouts = const [],
    this.isLoading = false,
    this.unavailable = false,
    this.error,
  });

  CashState copyWith({
    CashSummary? summary,
    List<PayoutModel>? payouts,
    bool? isLoading,
    bool? unavailable,
    String? error,
    bool clearError = false,
  }) {
    return CashState(
      summary: summary ?? this.summary,
      payouts: payouts ?? this.payouts,
      isLoading: isLoading ?? this.isLoading,
      unavailable: unavailable ?? this.unavailable,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CashNotifier extends StateNotifier<CashState> {
  final CashRepository _repo;
  CashNotifier(this._repo) : super(const CashState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([_repo.getSummary(), _repo.getPayouts()]);
      final summary = results[0] as CashSummary?;
      state = CashState(
        summary: summary,
        payouts: results[1] as List<PayoutModel>,
        unavailable: summary == null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: dioErrorMessage(e));
    }
  }

  /// Returns null on success, otherwise a message for the rider.
  Future<String?> remit({
    required double amount,
    required String mpesaCode,
  }) async {
    try {
      await _repo.remitCash(amount: amount, mpesaCode: mpesaCode);
      await load();
      return null;
    } catch (e) {
      return dioErrorMessage(e);
    }
  }

  /// Returns null on success, otherwise a message for the rider.
  Future<String?> requestPayout(PayoutRequest request) async {
    try {
      await _repo.requestPayout(request);
      await load();
      return null;
    } catch (e) {
      return dioErrorMessage(e);
    }
  }

  /// Called on logout, like the other providers.
  void reset() => state = const CashState();
}

final cashProvider = StateNotifierProvider<CashNotifier, CashState>(
  (ref) => CashNotifier(ref.read(cashRepositoryProvider)),
);
