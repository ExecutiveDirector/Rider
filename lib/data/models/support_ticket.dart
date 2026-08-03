// lib/data/models/support_ticket.dart

class TicketMessage {
  final int id;
  final String senderType; // user | rider | vendor | admin | system
  final String senderName;
  final String message;
  final bool isInternal;
  final DateTime sentAt;

  TicketMessage({
    required this.id,
    required this.senderType,
    required this.senderName,
    required this.message,
    required this.isInternal,
    required this.sentAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: json['message_id'] as int? ?? 0,
      senderType: json['sender_type'] as String? ?? 'system',
      senderName: json['sender_name'] as String? ?? 'Support',
      message: json['message_text'] as String? ?? '',
      isInternal: json['is_internal'] == true,
      sentAt: DateTime.tryParse(json['sent_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class SupportTicket {
  final int id;
  final String ticketNumber;
  final String subject;
  final String description;
  final String category;
  final String status; // open | in_progress | waiting_customer | resolved | closed
  final DateTime createdAt;
  final List<TicketMessage> messages;

  SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    required this.createdAt,
    this.messages = const [],
  });

  bool get isClosed => status == 'resolved' || status == 'closed';

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'waiting_customer':
        return 'Awaiting You';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['support_messages'] as List<dynamic>? ?? [];
    return SupportTicket(
      id: json['ticket_id'] as int? ?? 0,
      ticketNumber: json['ticket_number'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      messages: rawMessages
          .map((m) => TicketMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Matches the `category` ENUM on support_tickets/faqs — kept in one place
/// so the new-ticket form and the FAQ filter can't drift from each other.
class SupportCategory {
  static const values = [
    'order_issue',
    'delivery_problem',
    'payment_issue',
    'product_quality',
    'account_issue',
    'technical_support',
    'billing_inquiry',
    'other',
  ];

  static String label(String value) {
    switch (value) {
      case 'order_issue':
        return 'Order Issue';
      case 'delivery_problem':
        return 'Delivery Problem';
      case 'payment_issue':
        return 'Payment Issue';
      case 'product_quality':
        return 'Product Quality';
      case 'account_issue':
        return 'Account Issue';
      case 'technical_support':
        return 'Technical Support';
      case 'billing_inquiry':
        return 'Billing Inquiry';
      default:
        return 'Other';
    }
  }
}
