// lib/core/services/api_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';
import 'location_service.dart';
import 'provider_container.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/order_provider.dart';
import '../../data/providers/earnings_provider.dart';
import '../../data/providers/cash_provider.dart';
import '../../data/providers/support_provider.dart';

/// Global navigator key — set on MaterialApp so the auth interceptor can
/// push to /login from outside the widget tree when a token refresh fails.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  late final Dio _dio;

  void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout:
            const Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout:
            const Duration(milliseconds: ApiConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor());

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) {
    return _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) {
    return _dio.delete(path, data: data);
  }

  Future<Response> upload(String path, FormData formData) {
    return _dio.post(path, data: formData);
  }
}

/// Extracts a human-readable error message from a DioException.
/// Prefers the backend's JSON `error` or `message` field over raw Dio text.
String dioErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['error'] ?? data['message'] ?? data['msg'];
      if (msg != null) return msg.toString();
    }
    if (data is String && data.isNotEmpty) return data;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your internet.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      default:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await StorageService.instance.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // One refresh at a time: parallel 401s share the same attempt.
  static Future<String?>? _refreshing;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthCall = err.requestOptions.path.contains(ApiConstants.refreshToken) ||
        err.requestOptions.path.contains('/login');
    if (err.response?.statusCode == 401 &&
        !isAuthCall &&
        err.requestOptions.extra['retried'] != true) {
      final newToken =
          await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));
      if (newToken != null) {
        try {
          err.requestOptions.extra['retried'] = true;
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retryResponse =
              await ApiService.instance._dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
    }
    handler.next(err);
  }

  /// Returns a new access token, or null. Riders stay signed in: we only log
  /// out when the server definitively rejects the refresh token (401/403).
  /// Offline / server errors keep the session so the rider can retry.
  Future<String?> _refresh() async {
    final refreshToken = await StorageService.instance.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _forceLogout();
      return null;
    }
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ));
      final response = await dio.post(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      final newToken = response.data['token'] as String;
      await StorageService.instance.saveToken(newToken);
      final rotated = response.data['refreshToken'];
      if (rotated is String && rotated.isNotEmpty) {
        await StorageService.instance.saveRefreshToken(rotated);
      }
      return newToken;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) await _forceLogout();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _forceLogout() async {
    await StorageService.instance.clearAll();
    LocationService.instance.stopTracking();
    // FIX: this path (refresh-token failure) only ever cleared storage and
    // navigated to /login — it never touched Riverpod state, unlike the
    // manual logout buttons in Settings/Profile. So a session that expired
    // mid-use (rather than an explicit tap on "Logout") left the previous
    // rider's driver/orders/earnings sitting in memory: the login screen
    // showed, but anything that read those providers directly — without
    // re-fetching first — would still render stale data.
    appContainer.read(authProvider.notifier).state = const AuthState();
    appContainer.read(orderProvider.notifier).reset();
    appContainer.read(earningsProvider.notifier).reset();
    appContainer.read(cashProvider.notifier).reset();
    appContainer.read(supportProvider.notifier).reset();
    // FIX: navigate to login from anywhere in the app via the global key
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
