// lib/data/models/cash_models.dart
import '../../core/utils/json_utils.dart';

/// One cash-on-delivery payment the rider took from a customer.
class CashCollection {
  final String orderId;
  final String orderNumber;
  final double amount;
  final DateTime collectedAt;

  /// True once the rider has handed this cash over to AquaGas.
  final bool remitted;

  const CashCollection({
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.collectedAt,
    required this.remitted,
  });

  factory CashCollection.fromJson(Map<String, dynamic> json) {
    final orderId = (json['order_id'] ?? json['orderId'] ?? '').toString();
    final status = (json['status'] ?? '').toString().toLowerCase();
    return CashCollection(
      orderId: orderId,
      orderNumber:
          (json['order_number'] ?? json['orderNumber'] ?? orderId).toString(),
      amount: asDoubleOr(json['amount'] ?? json['cash_collected']),
      collectedAt: DateTime.tryParse(
              (json['collected_at'] ?? json['collectedAt'] ?? json['created_at'] ?? '')
                  .toString()) ??
          DateTime.now(),
      remitted: asBool(json['remitted']) ||
          status == 'remitted' ||
          status == 'settled',
    );
  }
}

/// The rider's COD cash position.
class CashSummary {
  /// Cash the rider is carrying that belongs to AquaGas.
  final double cashInHand;

  /// Ceiling set by AquaGas; above it the rider should remit before taking
  /// more cash jobs. 0 means "no limit configured".
  final double cashLimit;

  final double collectedToday;
  final double remittedToday;

  /// How to pay AquaGas (paybill / till and account), written by the backend
  /// so it can change without an app release.
  final String? instructions;

  final List<CashCollection> collections;

  const CashSummary({
    required this.cashInHand,
    required this.cashLimit,
    required this.collectedToday,
    required this.remittedToday,
    required this.collections,
    this.instructions,
  });

  /// 0..1 share of the limit in use (0 when no limit is configured).
  double get usage {
    if (cashLimit <= 0) return 0;
    final u = cashInHand / cashLimit;
    return u < 0 ? 0 : (u > 1 ? 1 : u);
  }

  bool get nearLimit => cashLimit > 0 && usage >= 0.8;
  bool get overLimit => cashLimit > 0 && cashInHand >= cashLimit;

  factory CashSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['collections'] as List? ?? const [];
    return CashSummary(
      cashInHand: asDoubleOr(json['cash_in_hand'] ?? json['cashInHand']),
      cashLimit: asDoubleOr(json['cash_limit'] ?? json['cashLimit']),
      collectedToday:
          asDoubleOr(json['collected_today'] ?? json['collectedToday']),
      remittedToday:
          asDoubleOr(json['remitted_today'] ?? json['remittedToday']),
      instructions:
          (json['instructions'] ?? json['remit_instructions'])?.toString(),
      collections: raw
          .whereType<Map>()
          .map((e) => CashCollection.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// A payment of the rider's earnings out to their M-Pesa.
class PayoutModel {
  final String id;
  final double amount;

  /// 'pending' | 'processing' | 'paid' | 'failed'
  final String status;
  final String? reference;
  final DateTime createdAt;

  const PayoutModel({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.reference,
  });

  bool get isPaid => status == 'paid' || status == 'completed';
  bool get isFailed => status == 'failed' || status == 'rejected';

  factory PayoutModel.fromJson(Map<String, dynamic> json) {
    return PayoutModel(
      id: (json['id'] ?? json['payout_id'] ?? '').toString(),
      amount: asDoubleOr(json['amount']),
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      reference: (json['reference'] ?? json['mpesa_receipt'])?.toString(),
      createdAt: DateTime.tryParse(
              (json['created_at'] ?? json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
