// lib/core/services/api_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';
import 'session_refresher.dart';
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

  /// Exposed so tests can swap the HTTP adapter.
  @visibleForTesting
  Dio get dioForTest => _dio;

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

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // A 401 normally just means the 8h access token ran out. Renew it and
    // retry the request once. Log the rider out ONLY if the server rejects
    // the refresh token itself; being offline or slow never logs anyone out.
    final path = err.requestOptions.path;
    final skip = err.response?.statusCode != 401 ||
        path.contains(ApiConstants.login) ||
        path.contains(ApiConstants.refreshToken) ||
        err.requestOptions.extra['session_retried'] == true;
    if (skip) return handler.next(err);

    final outcome = await SessionRefresher.refresh();
    if (outcome == RefreshOutcome.renewed) {
      final newToken = await StorageService.instance.getToken();
      final opts = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newToken'
        ..extra['session_retried'] = true;
      try {
        return handler.resolve(await ApiService.instance._dio.fetch(opts));
      } on DioException catch (retryError) {
        // The retry itself failed (e.g. 500): report that error, keep the session.
        return handler.next(retryError);
      }
    }
    if (outcome == RefreshOutcome.rejected) {
      await _forceLogout();
    }
    handler.next(err);
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
