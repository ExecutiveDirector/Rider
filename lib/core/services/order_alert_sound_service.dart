// lib/core/services/order_alert_sound_service.dart
//
// Why this exists:
//  The incoming-order bottom sheet (IncomingOrderSheet) previously relied
//  entirely on a single system notification sound — fired once, whenever
//  the FCM push / local notification happened to show. That's a single
//  "ding" that's easy to miss if the rider's phone is in a pocket, in a
//  bag, or mounted on a handlebar with road noise. Production delivery
//  apps (Uber, Bolt, Glovo) ring continuously — like an incoming call —
//  for as long as the accept/reject screen is up, so there's no way to
//  miss a new order.
//
// This service loops assets/sounds/order_alert.wav at max volume while
// the sheet is open, and stops the instant the rider accepts, rejects,
// or the auto-reject timeout fires. It deliberately does NOT try to run
// while the app is backgrounded/killed — that's what the FCM/local
// notification sound (NotificationService) already covers; this is only
// for the in-app moment where the rider is actively looking at the
// decision screen.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class OrderAlertSoundService {
  OrderAlertSoundService._();
  static final OrderAlertSoundService instance = OrderAlertSoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  /// Starts looping the alert tone. Safe to call repeatedly — a second
  /// call while already playing is a no-op rather than layering audio.
  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/order_alert.wav'));
    } catch (e) {
      debugPrint('[OrderAlertSound] Failed to play: $e');
      _isPlaying = false;
    }
  }

  /// Stops the loop. MUST be called on accept, reject, auto-reject
  /// timeout, and sheet dismissal — see IncomingOrderSheet.dispose().
  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[OrderAlertSound] Failed to stop: $e');
    }
  }

  Future<void> dispose() => _player.dispose();
}
