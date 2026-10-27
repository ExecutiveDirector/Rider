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
  static const String changePassword = '/riders/change-password';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Orders — all actions are PATCH /riders/orders/:id/<verb>
  static const String activeOrders = '/riders/orders/active';
  static const String completedOrders = '/riders/orders/completed';
  static const String ordersBase = '/riders/orders'; // + /:id[/verb]
  static const String pushTokenRegister = '/riders/push-token/register';
  static const String pushTest = '/riders/push-test';
  static const String pushTokenUnregister = '/riders/push-token/unregister';

  // Tracking
  static const String updateLocation = '/riders/location';
  static const String incentives = '/riders/incentives';
  static const String demandZones = '/riders/demand-zones';

  // Earnings
  static const String earnings = '/riders/earnings';
  static const String earningsSummary = '/riders/earnings/summary';

  // Cash on delivery + payouts
  static const String cashSummary = '/riders/cash';
  static const String cashRemit = '/riders/cash/remit';
  static const String payouts = '/riders/payouts';
  static const String payoutRequest = '/riders/payouts/request';

  // Profile
  static const String profile = '/riders/profile';
  static const String updateProfile = '/riders/profile';
  static const String uploadDocument = '/riders/profile/documents';

  // Support — was a bare mailto: link in the app; the backend already has
  // a full ticket system (used by the customer/vendor apps) at /support.
  static const String supportTickets = '/support/tickets';
  static const String supportFaq = '/support/faq';

  /// Free OSRM routing (no key). The public demo server is fine for launch
  /// volumes; point ROUTING_BASE_URL at your own OSRM / OpenRouteService
  /// instance via --dart-define when traffic grows.
  static const String routingBaseUrl = String.fromEnvironment(
    'ROUTING_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
}
