// lib/data/repositories/auth_repository.dart
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../models/driver_model.dart';

class AuthRepository {
  final _api     = ApiService.instance;
  final _storage = StorageService.instance;

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  /// Normalizes Kenyan phone numbers to E.164 (+254XXXXXXXXX).
  /// Leaves email addresses untouched.
  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+'))   return digits;
    if (digits.startsWith('0'))   return '+254${digits.substring(1)}';
    if (digits.startsWith('254')) return '+$digits';
    return '+254$digits';
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Accepts either a phone number (any Kenyan format) or an email address.
  /// FIX: the backend's riderLogin controller only ever reads `req.body.email`
  /// — it detects phone-vs-email *within that single field* using a regex,
  /// it does NOT also check a separate `phone` key. Previously this sent
  /// `{ phone, password }` for phone logins, so the backend saw no `email`
  /// key at all and returned "Email and password are required" every time.
  Future<DriverModel> login({
    required String identifier,
    required String password,
  }) async {
    final String value = _isEmail(identifier)
        ? identifier.trim().toLowerCase()
        : _normalizePhone(identifier.trim());

    final body = {
      'email':    value, // backend accepts phone OR email in this one field
      'password': password,
    };

    final response = await _api.post(ApiConstants.login, data: body);
    final data = response.data as Map<String, dynamic>;

    final token        = data['token'] as String;
    final refreshToken = data['refreshToken'] as String? ?? '';
    final driverData   = data['rider'] ?? data['driver'];

    await _storage.saveToken(token);
    if (refreshToken.isNotEmpty) await _storage.saveRefreshToken(refreshToken);

    final driver = DriverModel.fromJson(driverData);
    await _storage.saveDriverId(driver.id);
    return driver;
  }

  /// Step 1 of password reset — backend emails a reset link containing a
  /// token (not a short numeric OTP). Always returns success regardless of
  /// whether the email exists, to avoid leaking which emails are registered.
  Future<void> forgotPassword(String email) async {
    await _api.post(ApiConstants.forgotPassword, data: {
      'email': email.trim().toLowerCase(),
    });
  }

  /// Step 2 — the token is the one emailed in step 1 (copy/pasted from the
  /// reset link since the app has no deep-link handler for it yet).
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _api.post(ApiConstants.resetPassword, data: {
      'token': token.trim(),
      'newPassword': newPassword,
    });
  }

  /// Called on cold start — restores the DriverModel from the profile endpoint
  /// so the rest of the app sees a non-null driver without re-logging in.
  Future<DriverModel?> restoreSession() async {
    try {
      final response  = await _api.get(ApiConstants.profile);
      final data      = response.data as Map<String, dynamic>;
      final driverData = data['data'] ?? data['rider'] ?? data;
      return DriverModel.fromJson(driverData as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiConstants.logout);
    } catch (_) {
      // Clear local state regardless of API response
    } finally {
      await _storage.clearAll();
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null && token.isNotEmpty;
  }
}
