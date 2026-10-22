// lib/core/services/session_refresher.dart
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

/// What happened when we tried to renew the rider's session.
enum RefreshOutcome {
  /// New tokens were saved; the original request can be retried.
  renewed,

  /// The server says this session is over (signed out elsewhere, password
  /// reset, account disabled) or there is nothing to renew with. The only
  /// case in which a rider should be sent back to the login screen.
  rejected,

  /// Offline, timeout or server trouble. The session is most likely still
  /// valid, so riders must NOT be logged out for this (a rider in a basement
  /// car park or a dead zone mid-shift is still signed in).
  unavailable,
}

/// Quietly renews the 8h access token using the long-lived refresh token and
/// stores the replacement refresh token the server returns, which restarts the
/// 90-day window: a rider who works at least once every 90 days stays signed
/// in. Concurrent callers share a single renewal.
class SessionRefresher {
  SessionRefresher._();

  static Future<RefreshOutcome>? _inFlight;

  /// Test hooks.
  static Dio Function() dioFactory = () => Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout:
            const Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout:
            const Duration(milliseconds: ApiConstants.receiveTimeout),
      ));
  static StorageService storage = StorageService.instance;

  static Future<RefreshOutcome> refresh() {
    return _inFlight ??= _renew().whenComplete(() => _inFlight = null);
  }

  static Future<RefreshOutcome> _renew() async {
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return RefreshOutcome.rejected;
    }
    try {
      final res = await dioFactory().post(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      final data = res.data;
      final token = data is Map ? data['token'] : null;
      if (token is! String || token.isEmpty) return RefreshOutcome.unavailable;
      await storage.saveToken(token);
      final newRefresh = data['refreshToken'];
      if (newRefresh is String && newRefresh.isNotEmpty) {
        await storage.saveRefreshToken(newRefresh);
      }
      return RefreshOutcome.renewed;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) return RefreshOutcome.rejected;
      return RefreshOutcome.unavailable;
    } catch (_) {
      return RefreshOutcome.unavailable;
    }
  }
}
