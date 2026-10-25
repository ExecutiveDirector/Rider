// lib/features/orders/widgets/mpesa_collect_card.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../data/models/mpesa_request.dart';
import '../../../data/repositories/order_repository.dart';

/// "Collect payment" card for a cash-on-delivery order. Cashless first: the rider
/// asks for an M-Pesa payment, the server sends the STK push and only a verified
/// callback marks it paid. Cash stays available as an explicit fallback.
class MpesaCollectCard extends StatefulWidget {
  final String orderId;
  final double amount;
  final String customerPhone;
  final bool cashChosen;

  /// Fires whenever the request state changes (paid / pending / failed…).
  final ValueChanged<MpesaRequestState> onChanged;

  /// Rider chose to take cash instead (or M-Pesa is unavailable).
  final VoidCallback onUseCash;

  /// Rider wants to go back to M-Pesa after choosing cash.
  final VoidCallback onUseMpesa;

  const MpesaCollectCard({
    super.key,
    required this.orderId,
    required this.amount,
    required this.customerPhone,
    required this.cashChosen,
    required this.onChanged,
    required this.onUseCash,
    required this.onUseMpesa,
  });

  @override
  State<MpesaCollectCard> createState() => _MpesaCollectCardState();
}

class _MpesaCollectCardState extends State<MpesaCollectCard> {
  final _repo = OrderRepository();
  final _phoneCtrl = TextEditingController();

  MpesaRequestState _s = MpesaRequestState.none;
  Timer? _poll;
  Timer? _tick;
  DateTime? _deadline;
  int _left = 0;
  bool _busy = false;
  bool _otherNumber = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh(initial: true); // resume if a request is already live / paid
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _apply(MpesaRequestState s) {
    if (!mounted) return;
    final wasPaid = _s.isPaid;
    setState(() {
      _s = s;
      _error = null;
      if (s.isPending) {
        _deadline = DateTime.now().add(Duration(seconds: s.secondsLeft));
        _left = s.secondsLeft;
      }
    });
    _poll?.cancel();
    _tick?.cancel();
    if (s.isPending) {
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _deadline == null) return;
        final left = _deadline!.difference(DateTime.now()).inSeconds;
        setState(() => _left = left < 0 ? 0 : left);
      });
    }
    if (s.isPaid && !wasPaid) HapticFeedback.heavyImpact();
    widget.onChanged(s);
  }

  Future<void> _refresh({bool initial = false}) async {
    try {
      final s = await _repo.mpesaStatus(widget.orderId);
      // Don't let a stale poll wipe a state the rider just created.
      if (!initial && s.phase == MpesaPhase.none && _s.isPending) return;
      _apply(s);
    } on DioException catch (e) {
      // Older backend without the endpoint: fall back to plain cash.
      if (initial && e.response?.statusCode == 404) widget.onUseCash();
    } catch (_) {/* keep polling */}
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await _repo.requestMpesa(
        widget.orderId,
        phone: _otherNumber ? _phoneCtrl.text : null,
      );
      _apply(s);
    } catch (e) {
      if (mounted) setState(() => _error = dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _amountText =>
      'KES ${(_s.amount > 0 ? _s.amount : widget.amount).toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    if (_s.isPaid) return _paid();
    if (widget.cashChosen) return _cashChosen();
    return _shell(
      color: AppColors.primary,
      child: switch (_s.phase) {
        MpesaPhase.pending => _waiting(),
        MpesaPhase.failed => _retry(_s.reason ?? 'The payment was not completed.'),
        MpesaPhase.expired =>
          _retry('The request timed out before the customer paid.'),
        _ => _start(),
      },
    );
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _start() {
    final number = _otherNumber
        ? null
        : (widget.customerPhone.isEmpty ? null : widget.customerPhone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('Collect payment', Icons.phone_android_rounded),
        const SizedBox(height: 4),
        Text(_amountText,
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text(
          'Ask the customer to pay by M-Pesa — no cash to carry or remit.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (_otherNumber || number == null) ...[
          TextField(
            controller: _phoneCtrl,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            maxLength: 13,
            decoration: const InputDecoration(
              counterText: '',
              labelText: 'M-Pesa number',
              hintText: '0712 345 678',
              prefixIcon: Icon(Icons.dialpad_rounded),
              helperText: 'Only a number the customer has authorised.',
            ),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Customer\'s number  ${widget.customerPhone}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _otherNumber = true),
                  child: const Text('Use another'),
                ),
              ],
            ),
          ),
        if (_error != null) _errorBox(_error!),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _busy ? null : _send,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(_busy ? 'Sending…' : 'Request M-Pesa payment',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _busy ? null : widget.onUseCash,
            child: const Text('Customer is paying cash instead'),
          ),
        ),
      ],
    );
  }

  Widget _waiting() {
    final total = 180.0;
    final progress = (_left / total).clamp(0.0, 1.0);
    final mm = (_left ~/ 60).toString().padLeft(1, '0');
    final ss = (_left % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        _header('Waiting for payment', Icons.hourglass_top_rounded),
        const SizedBox(height: 16),
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  backgroundColor: AppColors.primaryLight,
                ),
              ),
              Text('$mm:$ss',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _s.phoneMasked != null && _s.phoneMasked!.isNotEmpty
              ? 'M-Pesa prompt sent to ${_s.phoneMasked}'
              : 'M-Pesa prompt sent',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('Ask the customer to enter their M-Pesa PIN for $_amountText.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 10),
        const Text('Don\'t take cash while this is waiting — it could be charged twice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _retry(String reason) {
    final tooMany = _s.attempts >= 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('Payment not completed', Icons.error_outline_rounded, color: AppColors.error),
        const SizedBox(height: 8),
        Text(reason, style: const TextStyle(color: AppColors.textPrimary)),
        if (_error != null) _errorBox(_error!),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: (_busy || tooMany) ? null : _send,
                child: Text(_busy ? 'Sending…' : 'Try again'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : widget.onUseCash,
                child: const Text('Take cash'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paid() {
    return _shell(
      color: AppColors.success,
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
          const SizedBox(height: 8),
          const Text('Payment received',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('$_amountText paid by M-Pesa',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (_s.receipt != null && _s.receipt!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Receipt ${_s.receipt}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          const Text('Nothing to collect or remit. Finish the hand-over below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _cashChosen() {
    return _shell(
      color: AppColors.warning,
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppColors.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Taking cash. It must be remitted to AquaGas.',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton(onPressed: widget.onUseMpesa, child: const Text('Use M-Pesa')),
        ],
      ),
    );
  }

  // ── Bits ──────────────────────────────────────────────────────────────────

  Widget _shell({required Color color, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.55), width: 1.5),
        ),
        child: child,
      );

  Widget _header(String title, IconData icon, {Color color = AppColors.primary}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        ],
      );

  Widget _errorBox(String msg) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(msg,
            style: const TextStyle(
                color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13)),
      );
}
