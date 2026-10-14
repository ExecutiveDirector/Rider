// lib/core/utils/navigation_launcher.dart
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens turn-by-turn navigation to [lat],[lng] in the rider's maps app.
///
/// On Android this asks Google Maps for its two-wheeler mode (`mode=l`),
/// which routes motorbikes through the shortcuts cars can't use. Everywhere
/// else — or if Google Maps isn't installed — it falls back to the universal
/// Maps URL, which opens in whatever maps app or browser is available.
///
/// Returns false if nothing could be launched.
Future<bool> launchNavigation(double lat, double lng) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final ok = await launchUrl(
        Uri.parse('google.navigation:q=$lat,$lng&mode=l'),
        mode: LaunchMode.externalApplication,
      );
      if (ok) return true;
    } catch (_) {
      // Fall through to the web URL.
    }
  }

  try {
    return await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
      ),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Opens the phone dialler for [phone]. Returns false if it couldn't.
Future<bool> launchPhoneCall(String phone) async {
  if (phone.trim().isEmpty) return false;
  try {
    return await launchUrl(Uri(scheme: 'tel', path: phone.trim()));
  } catch (_) {
    return false;
  }
}
