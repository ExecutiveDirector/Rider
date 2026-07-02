// lib/core/widgets/cancel_reason_dialog.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reason picker shown before declining/cancelling an order, so the reason
/// actually reaches the backend instead of being silently hardcoded.
class CancelReasonDialog {
  CancelReasonDialog._();

  static const List<String> quickReasons = [
    'Too far from my location',
    'Vehicle issue',
    'Already on another delivery',
    'Customer unreachable',
    'Other',
  ];

  /// Returns the chosen reason, or `null` if the rider backed out without
  /// picking one — callers should treat `null` as "do not proceed."
  static Future<String?> show(
    BuildContext context, {
    String title = 'Why are you declining?',
  }) {
    String? selected;
    final customCtrl = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...quickReasons.map(
                    (reason) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selected,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => selected = v),
                    ),
                  ),
                  if (selected == 'Other') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customCtrl,
                      autofocus: true,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Tell us more…',
                        isDense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () {
                        final reason = selected == 'Other'
                            ? (customCtrl.text.trim().isEmpty
                                ? 'Other'
                                : customCtrl.text.trim())
                            : selected!;
                        Navigator.pop(ctx, reason);
                      },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }
}
