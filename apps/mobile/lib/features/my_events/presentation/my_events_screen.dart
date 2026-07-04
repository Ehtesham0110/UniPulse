import 'package:flutter/material.dart';

class MyEventsScreen extends StatelessWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          Center(
            child: Text(
              'My Events',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(height: 28),
          _Tabs(),
          SizedBox(height: 24),
          Text(
            'Upcoming Events',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 14),
          _MyEventCard(
            title: 'Treasure Hunt',
            type: 'Non Tech',
            team: '4 Members',
            role: 'Team Leader',
          ),
          SizedBox(height: 14),
          _MyEventCard(
            title: 'HackVerse 3.0',
            type: 'Tech',
            team: '3 Members',
            role: 'Member',
          ),
          SizedBox(height: 24),
          Text(
            'Past Events',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 14),
          _MyEventCard(
            title: 'Singing Battle',
            type: 'Non Tech',
            team: 'Individual',
            role: 'Participant',
            past: true,
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();
  @override
  Widget build(BuildContext context) => Container(
        height: 58,
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFEDEDF2)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: const [
            Expanded(
              child: Center(
                child: Text(
                  'Registered',
                  style: TextStyle(
                    color: Color(0xFFFF6B1A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(child: Center(child: Text('Ongoing'))),
            Expanded(child: Center(child: Text('Completed'))),
          ],
        ),
      );
}

class _MyEventCard extends StatelessWidget {
  const _MyEventCard({
    required this.title,
    required this.type,
    required this.team,
    required this.role,
    this.past = false,
  });
  final String title;
  final String type;
  final String team;
  final String role;
  final bool past;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06), blurRadius: 14),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: type == 'Tech' ? Color(0xFFE8D8FF) : Color(0xFFFFE8A8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                type == 'Tech' ? Icons.laptop_mac : Icons.emoji_events,
                color: type == 'Tech' ? Color(0xFF8A42E8) : Color(0xFFFFAA00),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                      color: Color(0xFFFF6B1A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text('25 May, 2025  |  10:00 AM'),
                  const Text('Main Campus'),
                  const SizedBox(height: 8),
                  Text(
                    past ? 'Participated' : 'Confirmed',
                    style: const TextStyle(
                      color: Color(0xFF22A33A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Team Size  $team    Your Role  $role',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
}
