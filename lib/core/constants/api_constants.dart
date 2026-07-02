// lib/core/constants/api_constants.dart

class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://aquagas-backend.onrender.com/api/v1',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://aquagas-backend.onrender.com',
  );

  // Auth
  static const String login = '/riders/login';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Orders — all actions are PATCH /riders/orders/:id/<verb>
  static const String activeOrders = '/riders/orders/active';
  static const String completedOrders = '/riders/orders/completed';
  static const String ordersBase = '/riders/orders'; // + /:id[/verb]
  static const String pushTokenRegister = '/riders/push-token/register';

  // Tracking
  static const String updateLocation = '/riders/location';

  // Earnings
  static const String earnings = '/riders/earnings';
  static const String earningsSummary = '/riders/earnings/summary';

  // Profile
  static const String profile = '/riders/profile';
  static const String updateProfile = '/riders/profile';
  static const String uploadDocument = '/riders/profile/documents';

  static const String directionsApiKey = String.fromEnvironment(
    'DIRECTIONS_API_KEY',
    defaultValue: '',
  );

  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
}
