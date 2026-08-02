// lib/features/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/stat_tile.dart';
import '../../core/config/routes.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/notification_watcher_service.dart';
import '../../data/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(authProvider).driver;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                child: Stack(
                  children: [
                    Positioned(
                      top: -50,
                      left: -40,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accentMint.withOpacity(0.22),
                              AppColors.accentMint.withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage: driver?.avatarUrl != null
                                  ? NetworkImage(driver!.avatarUrl!)
                                  : null,
                              child: driver?.avatarUrl == null
                                  ? Text(
                                      driver?.name.substring(0, 1).toUpperCase() ??
                                          "R",
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            driver?.name ?? "Rider",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            driver?.phone ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.verified,
                                  color: Color(0xFFFBBF24),
                                  size: 16,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "Verified Rider",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStats(driver),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: "Profile",
                    children: [
                      _tile(
                        Icons.person_outline,
                        "Edit Profile",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.editProfile,
                        ),
                      ),
                      _tile(
                        Icons.phone_outlined,
                        "Emergency Contacts",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.emergencyContacts,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: "Vehicle",
                    children: [
                      _tile(
                        Icons.motorcycle_outlined,
                        "Vehicle Information",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.vehicleInfo,
                        ),
                      ),
                      _tile(
                        Icons.description_outlined,
                        "Documents",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.documents,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: "Performance",
                    children: [
                      _tile(
                        Icons.account_balance_wallet_outlined,
                        "Earnings",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.earnings,
                        ),
                      ),
                      _tile(
                        Icons.analytics_outlined,
                        "Performance Analytics",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.performance,
                        ),
                      ),
                      _tile(
                        Icons.history,
                        "Completed Orders",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.completedOrders,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: "Preferences",
                    children: [
                      _tile(
                        Icons.notifications_outlined,
                        "Notifications",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.notifications,
                        ),
                      ),
                      _tile(
                        Icons.settings_outlined,
                        "Settings",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.settings,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: "Security",
                    children: [
                      _tile(
                        Icons.lock_outline,
                        "Change Password",
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.changePassword,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withOpacity(0.2)),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: const Icon(
                        Icons.logout,
                        color: AppColors.error,
                      ),
                      title: const Text(
                        "Logout",
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Logout"),
                            content: const Text(
                              "Are you sure you want to logout?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Logout"),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          // Mirrors settings_screen.dart's logout cleanup —
                          // this was the one logout path missing socket
                          // disconnect / watcher reset / token unregister.
                          SocketService.instance.disconnect();
                          NotificationWatcherService.instance.reset();
                          await NotificationService.instance.unregisterToken();
                          await ref.read(authProvider.notifier).logout();

                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                              (_) => false,
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(dynamic driver) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.star,
            value: "${driver?.rating?.toStringAsFixed(1) ?? '0.0'}",
            label: "Rating",
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            icon: Icons.local_shipping,
            value: "${driver?.totalDeliveries ?? 0}",
            label: "Deliveries",
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            icon: Icons.check_circle,
            value: "Active",
            label: "Status",
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: AppColors.primary, size: 19),
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}
