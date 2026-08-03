// lib/data/models/faq_item.dart

class FaqItem {
  final int id;
  final String question;
  final String answer;
  final String category;
  final int helpfulCount;

  FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.helpfulCount,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: json['id'] as int? ?? 0,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      helpfulCount: json['helpful_count'] as int? ?? 0,
    );
  }
}
