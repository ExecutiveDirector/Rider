// lib/features/tracking/order_problem_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/order_provider.dart';

/// Reasons the rider can give; keys match the backend's FAIL_REASONS.
const _failReasons = <String, String>{
  'customer_unreachable': 'Customer not reachable',
  'customer_refused': 'Customer refused the order',
  'wrong_address': 'Address wrong / cannot be found',
  'no_cash': 'Customer cannot pay cash on delivery',
  'unsafe': 'Unsafe to deliver',
  'other': 'Other (add a note)',
};

const _releaseReasons = <String>[
  'Bike / vehicle problem',
  'Emergency',
  'Too far from my location',
  'Cannot reach the outlet',
];

/// Before pickup → "I can't deliver" (release the order back to dispatch).
/// After pickup → "Delivery failed" (close it with a reason; return the cylinder).
/// Resolves true when the order was removed from this rider.
Future<bool?> showOrderProblemSheet(
  BuildContext context,
  WidgetRef ref,
  OrderModel order, {
  double? lat,
  double? lng,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _ProblemSheet(
      order: order,
      ref: ref,
      lat: lat,
      lng: lng,
    ),
  );
}

class _ProblemSheet extends StatefulWidget {
  final OrderModel order;
  final WidgetRef ref;
  final double? lat, lng;
  const _ProblemSheet(
      {required this.order, required this.ref, this.lat, this.lng});

  @override
  State<_ProblemSheet> createState() => _ProblemSheetState();
}

class _ProblemSheetState extends State<_ProblemSheet> {
  String? _code; // failed-delivery reason key, or the release reason text
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _afterPickup => widget.order.status == OrderStatus.inTransit;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_code == null) return false;
    if (_afterPickup) {
      return _code != 'other' || _note.text.trim().length >= 3;
    }
    return true;
  }

  Future<void> _submit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_afterPickup ? 'Report failed delivery?' : 'Hand this order back?'),
        content: Text(_afterPickup
            ? 'The order will be closed. Return the cylinder to the vendor.'
            : 'Another rider will be found. Please only do this if you really cannot deliver.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final notifier = widget.ref.read(orderProvider.notifier);
    final err = _afterPickup
        ? await notifier.failDelivery(widget.order.id,
            reasonCode: _code!,
            note: _note.text.trim(),
            lat: widget.lat,
            lng: widget.lng)
        : await notifier.releaseOrder(
            widget.order.id,
            _note.text.trim().isEmpty
                ? _code!
                : '${_code!} — ${_note.text.trim()}');
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _afterPickup
        ? _failReasons.entries.map((e) => MapEntry(e.key, e.value)).toList()
        : _releaseReasons.map((r) => MapEntry(r, r)).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_afterPickup ? 'Delivery failed' : "I can't deliver this order",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_afterPickup
                ? 'Why could you not hand it over?'
                : 'Why can you not take it any more?'),
            const SizedBox(height: 8),
            for (final o in options)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: o.key,
                groupValue: _code,
                title: Text(o.value),
                onChanged: _busy ? null : (v) => setState(() => _code = v),
              ),
            TextField(
              controller: _note,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _code == 'other' ? 'What happened? (required)' : 'Note (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_valid && !_busy) ? _submit : null,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    minimumSize: const Size.fromHeight(50)),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(_afterPickup ? 'Report failed delivery' : 'Hand back order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
