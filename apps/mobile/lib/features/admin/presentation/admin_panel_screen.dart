import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEDEDF2)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 34, child: Icon(Icons.person)),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Hey, Admin\nSuper Admin',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(Icons.verified_user_outlined, color: Color(0xFFFF5A1A)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: const [
              _Stat('24', 'Total\nEvents', Icons.event),
              _Stat('12', 'Upcoming', Icons.event_available),
              _Stat('8', 'Ongoing', Icons.play_circle),
              _Stat('4', 'Completed', Icons.check_circle_outline),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              const _Action('Create Event', Icons.add_circle),
              const _Action('Participants', Icons.groups),
              _Action(
                'Certificates',
                Icons.workspace_premium,
                onTap: () => context.push('/admin/certificates'),
              ),
              const _Action('Notifications', Icons.campaign),
              const _Action('Admins', Icons.admin_panel_settings),
              const _Action('Analytics', Icons.bar_chart),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Recent Events',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const _RecentEvent('Treasure Hunt', 'Non Tech', 'Upcoming'),
          const _RecentEvent('HackVerse 3.0', 'Tech', 'Ongoing'),
          const _RecentEvent('BGMI Tournament', 'Non Tech', 'Upcoming'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFEDEDF2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Color(0xFFFF5A1A)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.icon, {this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEDEDF2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFFF5A1A)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

class _RecentEvent extends StatelessWidget {
  const _RecentEvent(this.title, this.type, this.status);
  final String title;
  final String type;
  final String status;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: type == 'Tech'
                ? const Color(0xFFE8D8FF)
                : const Color(0xFFFFE8A8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(type == 'Tech' ? Icons.laptop_mac : Icons.emoji_events),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('$type  •  25 May, 2025'),
        trailing: Text(
          status,
          style: const TextStyle(
            color: Color(0xFF22A33A),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
