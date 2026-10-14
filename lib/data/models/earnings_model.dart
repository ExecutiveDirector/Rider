// lib/data/models/earnings_model.dart
import '../../core/utils/json_utils.dart';

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
      amount: asDoubleOr(json['amount']),
      commission: asDoubleOr(json['commission']),
      netAmount: asDoubleOr(json['netAmount'] ?? json['net_amount']),
      date: DateTime.tryParse(
              (json['date'] ?? json['createdAt'] ?? json['created_at'] ?? '')
                  .toString()) ??
          DateTime.now(),
      status: (json['status'] ?? 'pending').toString(),
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
      today: asDoubleOr(json['today']),
      thisWeek: asDoubleOr(json['thisWeek'] ?? json['this_week']),
      thisMonth: asDoubleOr(json['thisMonth'] ?? json['this_month']),
      totalDeliveriesToday: asIntOr(
          json['totalDeliveriesToday'] ?? json['total_deliveries_today']),
      totalDeliveriesWeek: asIntOr(
          json['totalDeliveriesWeek'] ?? json['total_deliveries_week']),
      totalDeliveriesMonth: asIntOr(
          json['totalDeliveriesMonth'] ?? json['total_deliveries_month']),
      pendingPayout:
          asDoubleOr(json['pendingPayout'] ?? json['pending_payout']),
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
