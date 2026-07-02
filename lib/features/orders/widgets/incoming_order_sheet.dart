// lib/features/orders/widgets/incoming_order_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/config/routes.dart';
import '../../../core/widgets/cancel_reason_dialog.dart';
import '../../../data/models/order_model.dart';
import '../../../data/providers/order_provider.dart';

class IncomingOrderSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  const IncomingOrderSheet({super.key, required this.order});

  @override
  ConsumerState<IncomingOrderSheet> createState() => _IncomingOrderSheetState();
}

class _IncomingOrderSheetState extends ConsumerState<IncomingOrderSheet>
    with SingleTickerProviderStateMixin {
  static const _autoRejectSeconds = 20;
  int _remaining = _autoRejectSeconds;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  bool _isAccepting = false;
  // FIX: guard against auto-reject firing after manual accept/reject
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        _reject(auto: true);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _accept() async {
    if (_handled) return;
    _handled = true;
    _timer?.cancel();
    setState(() => _isAccepting = true);
    final success =
        await ref.read(orderProvider.notifier).acceptOrder(widget.order.id);
    if (mounted) {
      Navigator.pop(context);
      if (success) {
        Navigator.pushNamed(context, AppRoutes.orderDetails,
            arguments: widget.order.id);
      }
    }
  }

  void _reject({bool auto = false, String? customReason}) {
    if (_handled) return;
    _handled = true;
    _timer?.cancel();
    ref.read(orderProvider.notifier).rejectOrder(
          widget.order.id,
          reason: auto
              ? 'Auto-rejected (timeout)'
              : (customReason ?? 'Rider declined'),
        );
    if (mounted) Navigator.pop(context);
  }

  /// Manual reject: pause the countdown, ask why, then reject with that
  /// reason. If the rider backs out of the dialog without picking a reason,
  /// we leave the countdown stopped rather than guessing — they can tap
  /// Reject again or Accept.
  Future<void> _onRejectPressed() async {
    _timer?.cancel();
    final reason = await CancelReasonDialog.show(context);
    if (reason == null || !mounted) return;
    _reject(customReason: reason);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / _autoRejectSeconds;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with timer
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.warning
                        .withOpacity(0.1 + 0.1 * _pulseCtrl.value),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🔥', style: TextStyle(fontSize: 22)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'New Order!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Countdown circle
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.divider,
                      color:
                          progress > 0.4 ? AppColors.warning : AppColors.error,
                      strokeWidth: 3,
                    ),
                    Text(
                      '$_remaining',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Order details
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Customer',
            value: widget.order.customerName,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Deliver to',
            value: widget.order.deliveryAddress,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.local_fire_department_outlined,
            label: 'Gas',
            value: '${widget.order.quantity}kg ${widget.order.gasType}',
          ),
          if (widget.order.distanceKm != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.directions_outlined,
              label: 'Distance',
              value: '${widget.order.distanceKm!.toStringAsFixed(1)} km',
            ),
          ],

          const SizedBox(height: 16),

          // Earnings highlight
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFF00A577)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'You earn',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  'KES ${widget.order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isAccepting ? null : _onRejectPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isAccepting ? null : _accept,
                  child: _isAccepting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Accept Order'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
