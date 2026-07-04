import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/campus_tree_footer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 155),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.menu_rounded),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text.rich(
                        TextSpan(
                          text: 'Uni',
                          children: [
                            TextSpan(
                              text: 'Pulse',
                              style: TextStyle(color: Color(0xFFFF4F16)),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFFE7F6E6),
                    child: Icon(
                      Icons.person,
                      size: 42,
                      color: Color(0xFF24A546),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hey, Ehtesham',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          children: const [
                            Text(
                              'Second Year, ECS',
                              style: TextStyle(color: Color(0xFF65687A)),
                            ),
                            _RollBadge(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'Explore Events',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a category to get started',
                style: TextStyle(color: Color(0xFF65687A)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _CategoryCard(
                      label: 'Non Tech\nEvents',
                      subtitle: 'Fun. Creative.\nBeyond Tech.',
                      color: Color(0xFFFFE7A3),
                      icon: Icons.emoji_events_rounded,
                      onTap: () => context.push('/events/Non Tech'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CategoryCard(
                      label: 'Tech\nEvents',
                      subtitle: 'Innovate. Build.\nCompete.',
                      color: Color(0xFFDCC5FF),
                      icon: Icons.code_rounded,
                      onTap: () => context.push('/events/Tech'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Upcoming Highlights',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'View all',
                    style: TextStyle(
                      color: Color(0xFFFF5A1A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _HighlightCard(),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CampusTreeFooter(height: 130),
          ),
        ],
      ),
    );
  }
}

class _RollBadge extends StatelessWidget {
  const _RollBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD9F8D9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'VU3F2526129',
          style:
              TextStyle(color: Color(0xFF22A33A), fontWeight: FontWeight.w700),
        ),
      );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 52, color: const Color(0xFFFF851A)),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07), blurRadius: 18),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0CE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'MAY\n24',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HackVerse 3.0',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text('24 May, 2025  |  10:00 AM'),
                  SizedBox(height: 6),
                  Text('Seminar Hall'),
                  SizedBox(height: 10),
                  Text(
                    'Innovation starts here. Are you in?',
                    style: TextStyle(color: Color(0xFF65687A)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.bookmark_border_rounded),
          ],
        ),
      );
}
