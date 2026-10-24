/// M-Pesa-at-the-door state for a cash-on-delivery order, as decided by the
/// server. [state]: none | waiting | expired | failed | paid.
class CodPayment {
  final String state;
  final double amount;
  final int secondsLeft;
  final String? reason;
  final bool canRequest;

  const CodPayment({
    this.state = 'none',
    this.amount = 0,
    this.secondsLeft = 0,
    this.reason,
    this.canRequest = true,
  });

  bool get isPaid => state == 'paid';
  bool get isWaiting => state == 'waiting';

  factory CodPayment.fromJson(Map<String, dynamic> j) => CodPayment(
        state: (j['state'] ?? 'none').toString(),
        amount: double.tryParse('${j['amount']}') ?? 0,
        secondsLeft: int.tryParse('${j['seconds_left']}') ?? 0,
        reason: j['reason']?.toString(),
        canRequest: j['can_request'] != false,
      );
}
