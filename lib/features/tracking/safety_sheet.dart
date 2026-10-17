// lib/features/tracking/safety_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/navigation_launcher.dart';

/// Support number, injected at build time: --dart-define=SUPPORT_PHONE=+2547...
const String kSupportPhone = String.fromEnvironment('SUPPORT_PHONE');

/// Kenya's national emergency numbers.
const String kEmergencyPhone = '999';

/// One-tap help while on a delivery: call support, call emergency services,
/// or copy a live-location link to send to someone.
Future<void> showSafetySheet(
  BuildContext context, {
  double? lat,
  double? lng,
  String? orderNumber,
  String? problemTitle,
  String? problemSubtitle,
  VoidCallback? onProblem,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need help?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _Action(
              icon: Icons.local_police_outlined,
              color: AppColors.error,
              title: 'Call emergency services',
              subtitle: kEmergencyPhone,
              onTap: () async {
                Navigator.pop(ctx);
                await launchPhoneCall(kEmergencyPhone);
              },
            ),
            if (kSupportPhone.isNotEmpty)
              _Action(
                icon: Icons.support_agent,
                color: AppColors.primary,
                title: 'Call AquaGas support',
                subtitle: orderNumber == null
                    ? kSupportPhone
                    : '$kSupportPhone · mention order #$orderNumber',
                onTap: () async {
                  Navigator.pop(ctx);
                  await launchPhoneCall(kSupportPhone);
                },
              ),
            if (onProblem != null)
              _Action(
                icon: Icons.report_problem_outlined,
                color: AppColors.warning,
                title: problemTitle ?? "I can't deliver this order",
                subtitle: problemSubtitle ?? 'Tell us what happened',
                onTap: () {
                  Navigator.pop(ctx);
                  onProblem();
                },
              ),
            if (lat != null && lng != null)
              _Action(
                icon: Icons.share_location_outlined,
                color: AppColors.info,
                title: 'Copy my location link',
                subtitle: 'Paste it to a friend or support',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(
                      text: 'https://maps.google.com/?q=$lat,$lng'));
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Location link copied'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
