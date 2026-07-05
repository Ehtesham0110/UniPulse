import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../core/widgets/campus_tree_footer.dart';
import '../../auth/application/auth_controller.dart';
import '../../events/application/event_providers.dart';
import '../../events/data/event_api.dart';
import '../../events/domain/event_summary.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final highlightsAsync = ref.watch(eventListProvider(const EventListQuery()));

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
                        Text(
                          user != null ? 'Hey, ${user.fullName.split(' ').first}' : 'Hey there',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          children: [
                            Text(
                              user != null ? '${_yearLabel(user.year)}, ${user.branch}' : '',
                              style: const TextStyle(color: Color(0xFF65687A)),
                            ),
                            if (user != null && user.rollNumber.isNotEmpty)
                              _RollBadge(rollNumber: user.rollNumber),
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
                      color: const Color(0xFFFFE7A3),
                      icon: Icons.emoji_events_rounded,
                      onTap: () => context.push('/events/Non Tech'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CategoryCard(
                      label: 'Tech\nEvents',
                      subtitle: 'Innovate. Build.\nCompete.',
                      color: const Color(0xFFDCC5FF),
                      icon: Icons.code_rounded,
                      onTap: () => context.push('/events/Tech'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Upcoming Highlights',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              highlightsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Could not load upcoming events right now.',
                    style: TextStyle(color: Color(0xFF696C7E)),
                  ),
                ),
                data: (events) {
                  final upcoming = events.take(3).toList();
                  if (upcoming.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No upcoming events yet — check back soon!',
                        style: TextStyle(color: Color(0xFF696C7E)),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final event in upcoming) ...[
                        _HighlightCard(event: event),
                        const SizedBox(height: 14),
                      ],
                    ],
                  );
                },
              ),
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

  String _yearLabel(int year) {
    switch (year) {
      case 1:
        return 'First Year';
      case 2:
        return 'Second Year';
      case 3:
        return 'Third Year';
      case 4:
        return 'Fourth Year';
      default:
        return 'Year $year';
    }
  }
}

class _RollBadge extends StatelessWidget {
  const _RollBadge({required this.rollNumber});
  final String rollNumber;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD9F8D9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          rollNumber,
          style: const TextStyle(color: Color(0xFF22A33A), fontWeight: FontWeight.w700),
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

class _HighlightCard extends ConsumerWidget {
  const _HighlightCard({required this.event});
  final EventSummary event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLabel = event.eventDate != null ? formatEventDate(event.eventDate!) : 'Date TBA';

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 18),
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
              child: Center(
                child: Icon(
                  event.isTech ? Icons.laptop_mac_rounded : Icons.emoji_events_rounded,
                  color: const Color(0xFFFF851A),
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('$dateLabel  |  ${event.startTime.isEmpty ? 'TBA' : event.startTime}'),
                  const SizedBox(height: 6),
                  Text(event.venue),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                event.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: event.isBookmarked ? const Color(0xFFFF6B1A) : null,
              ),
              onPressed: () => toggleEventBookmark(ref, event.id),
            ),
          ],
        ),
      ),
    );
  }
}
