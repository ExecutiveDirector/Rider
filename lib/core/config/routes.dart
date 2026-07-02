// lib/core/config/routes.dart
import 'package:flutter/material.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/orders/active_orders_screen.dart';
import '../../features/orders/order_details_screen.dart';
import '../../features/orders/completed_orders_screen.dart';
import '../../features/tracking/live_tracking_screen.dart';
import '../../features/earnings/earnings_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/emergency_contacts_screen.dart';
import '../../features/profile/screens/vehicle_info_screen.dart';
import '../../features/profile/screens/performance_screen.dart';
import '../../features/profile/screens/rider_documents_screen.dart';
import '../../features/profile/screens/change_password_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String activeOrders = '/orders/active';
  static const String orderDetails = '/orders/details';
  static const String completedOrders = '/orders/completed';
  static const String liveTracking = '/tracking/live';
  static const String earnings = '/earnings';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String editProfile = '/profile/edit';
  static const String emergencyContacts = '/profile/emergency';
  static const String vehicleInfo = '/profile/vehicle';
  static const String performance = '/profile/performance';
  static const String documents = '/profile/documents';
  static const String changePassword = '/profile/password';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        otp: (ctx) =>
            OtpScreen(phone: ModalRoute.of(ctx)!.settings.arguments as String),
        forgotPassword: (_) => const ForgotPasswordScreen(),
        home: (_) => const HomeScreen(),
        activeOrders: (_) => const ActiveOrdersScreen(),
        completedOrders: (_) => const CompletedOrdersScreen(),
        earnings: (_) => const EarningsScreen(),
        profile: (_) => const ProfileScreen(),
        notifications: (_) => const NotificationsScreen(),
        settings: (_) => const SettingsScreen(),
        editProfile: (_) => const EditProfileScreen(),
        emergencyContacts: (_) => const EmergencyContactsScreen(),
        vehicleInfo: (_) => const VehicleInfoScreen(),
        performance: (_) => const PerformanceScreen(),
        documents: (_) => const RiderDocumentsScreen(),
        changePassword: (_) => const ChangePasswordScreen(),
      };

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case orderDetails:
        final orderId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(orderId: orderId),
        );
      case liveTracking:
        final orderId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => LiveTrackingScreen(orderId: orderId),
        );
      default:
        return null;
    }
  }
}
