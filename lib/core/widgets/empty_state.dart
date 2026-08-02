// lib/core/widgets/empty_state.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A consistent empty / error state: a soft gradient icon badge, a title,
/// an optional message, and an optional action button.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 24 : 48,
        horizontal: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 64 : 84,
            height: compact ? 64 : 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.16), color.withOpacity(0.06)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: compact ? 30 : 38, color: color),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 46)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
