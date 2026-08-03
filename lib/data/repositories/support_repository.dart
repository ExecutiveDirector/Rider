// lib/data/repositories/support_repository.dart
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../models/support_ticket.dart';
import '../models/faq_item.dart';

class SupportRepository {
  final ApiService _api = ApiService.instance;

  Future<List<SupportTicket>> getMyTickets() async {
    final response = await _api.get(ApiConstants.supportTickets);
    final list = response.data as List<dynamic>;
    return list
        .map((t) => SupportTicket.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<SupportTicket> getTicketDetails(String ticketId) async {
    final response =
        await _api.get('${ApiConstants.supportTickets}/$ticketId');
    return SupportTicket.fromJson(response.data);
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String category,
  }) async {
    final response = await _api.post(
      ApiConstants.supportTickets,
      data: {
        'subject': subject,
        'description': description,
        'category': category,
      },
    );
    // createTicket only returns the ticket row itself (no support_messages
    // include), so build a client-side copy with the description surfaced
    // as the first message rather than immediately re-fetching.
    return SupportTicket.fromJson(response.data['data']);
  }

  Future<TicketMessage> addMessage({
    required String ticketId,
    required String message,
  }) async {
    final response = await _api.post(
      '${ApiConstants.supportTickets}/$ticketId/messages',
      data: {'message': message},
    );
    return TicketMessage.fromJson(response.data['data']);
  }

  Future<List<FaqItem>> getFaq({String? category}) async {
    final response = await _api.get(
      ApiConstants.supportFaq,
      params: category != null ? {'category': category} : null,
    );
    final list = response.data as List<dynamic>;
    return list.map((f) => FaqItem.fromJson(f as Map<String, dynamic>)).toList();
  }
}
