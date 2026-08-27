import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final canSeeAdmin = user?.role.canSeeAdminPanel ?? false;
    final roleName = user?.role.name ?? 'student';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Center(
            child: Text(
              'Profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(0xFFE7F6E6),
                  child: Icon(Icons.person, size: 58, color: Color(0xFF24A546)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user != null
                            ? 'Hey, ${user.fullName.split(' ').first}'
                            : 'Hey there',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user != null
                            ? '${_yearLabel(user.year)}, ${user.branch}'
                            : '',
                      ),
                      if (user != null && user.rollNumber.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          user.rollNumber,
                          style: const TextStyle(
                            color: Color(0xFF22A33A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(user?.phone ?? ''),
                      if (roleName != 'student') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A1A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            roleName == 'superAdmin'
                                ? 'Super Admin'
                                : roleName[0].toUpperCase() +
                                    roleName.substring(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF5A1A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Account',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _MenuTile(
            icon: Icons.person_outline,
            title: 'Personal Information',
            subtitle: 'View and update your personal details',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.favorite_border,
            title: 'Saved Events',
            subtitle: 'Events you have saved for later',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Manage app preferences',
            onTap: () {},
          ),
          if (canSeeAdmin)
            _MenuTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin Panel',
              subtitle: 'Manage events, clubs and analytics',
              onTap: () => context.push('/admin'),
            ),
          _MenuTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'Sign out from your account',
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  static String _yearLabel(int year) {
    switch (year) {
      case 1:
        return '1st Year';
      case 2:
        return '2nd Year';
      case 3:
        return '3rd Year';
      case 4:
        return '4th Year';
      default:
        return '${year}th Year';
    }
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDEDF2)),
        ),
        child: ListTile(
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFECE4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFFF5A1A)),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
