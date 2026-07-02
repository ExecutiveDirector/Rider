// lib/data/models/earnings_model.dart

class EarningsModel {
  final String id;
  final String orderId;
  final double amount;
  final double commission;
  final double netAmount;
  final DateTime date;
  final String status; // 'pending' | 'paid'

  const EarningsModel({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.commission,
    required this.netAmount,
    required this.date,
    required this.status,
  });

  factory EarningsModel.fromJson(Map<String, dynamic> json) {
    return EarningsModel(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? json['order_id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      commission: (json['commission'] ?? 0).toDouble(),
      netAmount: (json['netAmount'] ?? json['net_amount'] ?? 0).toDouble(),
      date: DateTime.tryParse(json['date'] ?? json['createdAt'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'pending',
    );
  }
}

class EarningsSummary {
  final double today;
  final double thisWeek;
  final double thisMonth;
  final int totalDeliveriesToday;
  final int totalDeliveriesWeek;
  final int totalDeliveriesMonth;
  final double pendingPayout;

  const EarningsSummary({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.totalDeliveriesToday,
    required this.totalDeliveriesWeek,
    required this.totalDeliveriesMonth,
    required this.pendingPayout,
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    return EarningsSummary(
      today: (json['today'] ?? 0).toDouble(),
      thisWeek: (json['thisWeek'] ?? json['this_week'] ?? 0).toDouble(),
      thisMonth: (json['thisMonth'] ?? json['this_month'] ?? 0).toDouble(),
      totalDeliveriesToday: json['totalDeliveriesToday'] ?? json['total_deliveries_today'] ?? 0,
      totalDeliveriesWeek: json['totalDeliveriesWeek'] ?? json['total_deliveries_week'] ?? 0,
      totalDeliveriesMonth: json['totalDeliveriesMonth'] ?? json['total_deliveries_month'] ?? 0,
      pendingPayout: (json['pendingPayout'] ?? json['pending_payout'] ?? 0).toDouble(),
    );
  }

  static EarningsSummary empty() => const EarningsSummary(
    today: 0,
    thisWeek: 0,
    thisMonth: 0,
    totalDeliveriesToday: 0,
    totalDeliveriesWeek: 0,
    totalDeliveriesMonth: 0,
    pendingPayout: 0,
  );
}
