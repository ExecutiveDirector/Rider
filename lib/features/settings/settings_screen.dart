// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/config/routes.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/notification_watcher_service.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool notificationsEnabled = true;
  bool biometricEnabled = false;
  String appVersion = '';

  static const _prefNotifications = 'pref_notifications';
  static const _prefBiometric = 'pref_biometric';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAppVersion();
  }

  Future<void> _loadPrefs() async {
    final storage = StorageService.instance;
    setState(() {
      notificationsEnabled =
          storage.getBool(_prefNotifications, defaultValue: true);
      biometricEnabled =
          storage.getBool(_prefBiometric, defaultValue: false);
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(
          () => appVersion = '${info.version} (${info.buildNumber})');
    }
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => notificationsEnabled = value);
    await StorageService.instance.setBool(_prefNotifications, value);
  }

  Future<void> _setBiometric(bool value) async {
    setState(() => biometricEnabled = value);
    await StorageService.instance.setBool(_prefBiometric, value);
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // FIX: disconnect socket, stop the notification watcher, unregister
    // this device's push token, clear auth state, navigate to login —
    // otherwise the watcher keeps polling under the next rider's session
    // and a stale token stays registered against this rider's account.
    SocketService.instance.disconnect();
    NotificationWatcherService.instance.reset();
    await NotificationService.instance.unregisterToken();
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionTitle('Account'),
          _tile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Manage your account information',
            onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
          _tile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.changePassword),
          ),
          const Divider(),

          _sectionTitle('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive order and delivery updates'),
            value: notificationsEnabled,
            onChanged: _setNotifications,
          ),
          const Divider(),

          _sectionTitle('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme throughout the app'),
            // FIX: reads from and writes to real themeModeProvider
            value: isDark,
            onChanged: (v) => ref
                .read(themeModeProvider.notifier)
                .setMode(v ? ThemeMode.dark : ThemeMode.light),
          ),
          const Divider(),

          _sectionTitle('Security'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric Login'),
            subtitle: const Text('Use fingerprint or face unlock'),
            value: biometricEnabled,
            onChanged: _setBiometric,
          ),
          const Divider(),

          _sectionTitle('Support'),
          _tile(
            icon: Icons.contact_support_outlined,
            title: 'Contact Support',
            subtitle: 'Get assistance from AquaGas',
            onTap: () => _launch('mailto:support@aquagas.co.ke'),
          ),
          _tile(
            icon: Icons.article_outlined,
            title: 'Terms & Conditions',
            onTap: () => _launch('https://aquagas.co.ke/terms'),
          ),
          _tile(
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            onTap: () => _launch('https://aquagas.co.ke/privacy'),
          ),
          const Divider(),

          _sectionTitle('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            trailing: Text(
              appVersion.isEmpty ? '...' : appVersion,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: _logout,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primary,
          ),
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(color: AppColors.textSecondary))
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
