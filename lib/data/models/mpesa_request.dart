// lib/data/models/mpesa_request.dart

/// Where a rider-initiated M-Pesa request for a cash order stands.
/// Mirrors `mpesa` in POST/GET /riders/orders/:id/mpesa/* (see RIDER_API_CONTRACT.md).
enum MpesaPhase { none, pending, paid, failed, expired }

class MpesaRequestState {
  final MpesaPhase phase;
  final double amount;
  final int secondsLeft;
  final String? receipt;
  final String? reason;

  /// Masked number the prompt went to, e.g. `0712 *** 678`.
  final String? phoneMasked;
  final int attempts;

  const MpesaRequestState({
    this.phase = MpesaPhase.none,
    this.amount = 0,
    this.secondsLeft = 0,
    this.receipt,
    this.reason,
    this.phoneMasked,
    this.attempts = 0,
  });

  static const none = MpesaRequestState();

  bool get isPending => phase == MpesaPhase.pending;
  bool get isPaid => phase == MpesaPhase.paid;

  factory MpesaRequestState.fromJson(Map<String, dynamic> json) {
    final raw = (json['state'] ?? 'none').toString();
    final phase = MpesaPhase.values.firstWhere(
      (p) => p.name == raw,
      orElse: () => MpesaPhase.none,
    );
    double asDouble(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    return MpesaRequestState(
      phase: phase,
      amount: asDouble(json['amount']),
      secondsLeft: (json['seconds_left'] is num)
          ? (json['seconds_left'] as num).toInt()
          : 0,
      receipt: json['receipt']?.toString(),
      reason: json['reason']?.toString(),
      phoneMasked: json['phone']?.toString(),
      attempts: (json['attempts'] is num) ? (json['attempts'] as num).toInt() : 0,
    );
  }
}
