// lib/data/providers/support_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/support_ticket.dart';
import '../models/faq_item.dart';
import '../repositories/support_repository.dart';

class SupportState {
  final List<SupportTicket> tickets;
  final List<FaqItem> faqs;
  final bool isLoading;
  final String? error;

  const SupportState({
    this.tickets = const [],
    this.faqs = const [],
    this.isLoading = false,
    this.error,
  });

  SupportState copyWith({
    List<SupportTicket>? tickets,
    List<FaqItem>? faqs,
    bool? isLoading,
    String? error,
  }) {
    return SupportState(
      tickets: tickets ?? this.tickets,
      faqs: faqs ?? this.faqs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SupportNotifier extends StateNotifier<SupportState> {
  final SupportRepository _repo = SupportRepository();

  SupportNotifier() : super(const SupportState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([_repo.getMyTickets(), _repo.getFaq()]);
      state = state.copyWith(
        tickets: results[0] as List<SupportTicket>,
        faqs: results[1] as List<FaqItem>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<SupportTicket?> createTicket({
    required String subject,
    required String description,
    required String category,
  }) async {
    try {
      final ticket = await _repo.createTicket(
        subject: subject,
        description: description,
        category: category,
      );
      state = state.copyWith(tickets: [ticket, ...state.tickets]);
      return ticket;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Called on logout — same reasoning as OrderNotifier.reset().
  void reset() => state = const SupportState();
}

final supportProvider =
    StateNotifierProvider<SupportNotifier, SupportState>((ref) {
  return SupportNotifier();
});
