// lib/features/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/config/routes.dart';
import '../../data/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(authProvider).driver;

    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: driver?.avatarUrl != null
                          ? NetworkImage(driver!.avatarUrl!)
                          : null,
                      child: driver?.avatarUrl == null
                          ? Text(
                              driver?.name.substring(0, 1).toUpperCase() ?? "R",
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.verified,
                          color: Colors.greenAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "Verified Rider",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
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
                  Card(
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.red,
                      ),
                      title: const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.red,
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
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Logout"),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
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
          child: _statCard(
            Icons.star,
            "${driver?.rating?.toStringAsFixed(1) ?? '0.0'}",
            "Rating",
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            Icons.local_shipping,
            "${driver?.totalDeliveries ?? 0}",
            "Deliveries",
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            Icons.check_circle,
            "Active",
            "Status",
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
