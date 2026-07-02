// lib/core/constants/app_strings.dart
class AppStrings {
  AppStrings._();

  static const String appName = 'AquaGas Rider';
  static const String login = 'Login';
  static const String phoneNumber = 'Phone Number';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String sendOtp = 'Send OTP';
  static const String verifyOtp = 'Verify OTP';

  static const String home = 'Home';
  static const String activeOrders = 'Active Orders';
  static const String completedOrders = 'Completed Orders';
  static const String earnings = 'Earnings';
  static const String profile = 'Profile';

  static const String goOnline = 'Go Online';
  static const String goOffline = 'Go Offline';
  static const String acceptOrder = 'Accept Order';
  static const String rejectOrder = 'Reject';
  static const String startDelivery = 'Start Delivery';
  static const String completeDelivery = 'Complete Delivery';

  static const String newOrderAlert = 'New Order!';
  static const String orderCancelled = 'Order Cancelled';
  static const String paymentReceived = 'Payment Received';

  static const String noActiveOrders = 'No active orders right now';
  static const String networkError = 'Network error. Please check your connection.';
  static const String serverError = 'Something went wrong. Please try again.';
  static const String sessionExpired = 'Session expired. Please login again.';
}

// lib/core/constants/app_sizes.dart
class AppSizes {
  AppSizes._();

  // Padding
  static const double paddingXS = 4.0;
  static const double paddingSM = 8.0;
  static const double paddingMD = 16.0;
  static const double paddingLG = 24.0;
  static const double paddingXL = 32.0;

  // Border radius
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusCircle = 100.0;

  // Icon sizes
  static const double iconSM = 16.0;
  static const double iconMD = 24.0;
  static const double iconLG = 32.0;

  // Button height
  static const double buttonHeight = 52.0;
  static const double buttonHeightSM = 40.0;

  // Card elevation
  static const double elevationSM = 2.0;
  static const double elevationMD = 4.0;
  static const double elevationLG = 8.0;

  // Map
  static const double mapHeight = 300.0;
  static const double orderCardNewOrderTimerSeconds = 20.0; // auto-reject after
}
