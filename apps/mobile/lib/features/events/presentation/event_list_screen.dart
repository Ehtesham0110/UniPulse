import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EventListScreen extends StatelessWidget {
  const EventListScreen({required this.category, super.key});

  final String category;

  bool get isTech =>
      category.toLowerCase().contains('tech') &&
      !category.toLowerCase().contains('non');

  @override
  Widget build(BuildContext context) {
    final accent = isTech ? const Color(0xFF8A42E8) : const Color(0xFFFFAA00);
    final bg = isTech ? const Color(0xFFF1E8FF) : const Color(0xFFFFF4CF);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$category Events',
          style: TextStyle(color: accent, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: [
          Container(
            height: 130,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isTech
                        ? 'Explore innovative, challenging and future-ready tech events.'
                        : 'Explore fun, creative and exciting non-technical events.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  isTech
                      ? Icons.laptop_mac_rounded
                      : Icons.emoji_events_rounded,
                  color: accent,
                  size: 74,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: ['All', 'Upcoming', 'Past']
                .map(
                  (label) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: label == 'All' ? accent : Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: label == 'All'
                              ? Colors.white
                              : const Color(0xFF222433),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          for (final event in _events(isTech)) ...[
            _EventCard(
              event: event,
              accent: accent,
              onTap: () => context.push('/event/${event.title}'),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  List<_EventData> _events(bool tech) => tech
      ? const [
          _EventData(
            'Hackathon 3.0',
            '24 May, 2025',
            '10:00 AM',
            'Seminar Hall',
            'Code. Innovate. Build solutions that make an impact!',
            Icons.laptop_mac_rounded,
          ),
          _EventData(
            'Circuit Building',
            '26 May, 2025',
            '02:00 PM',
            'ECS Lab',
            'Design, build and showcase your electronics skills!',
            Icons.memory_rounded,
          ),
          _EventData(
            'Robo Challenge',
            '28 May, 2025',
            '11:00 AM',
            'Robotics Lab',
            'Build intelligent robots and compete to win!',
            Icons.smart_toy_rounded,
          ),
        ]
      : const [
          _EventData(
            'Treasure Hunt',
            '25 May, 2025',
            '10:00 AM',
            'Main Campus',
            'Find clues, solve puzzles and be the ultimate treasure finder!',
            Icons.emoji_events_rounded,
          ),
          _EventData(
            'BGMI Tournament',
            '27 May, 2025',
            '02:00 PM',
            'Gaming Arena',
            'Squad up and battle it out for glory and amazing prizes!',
            Icons.sports_esports_rounded,
          ),
          _EventData(
            'Singing Battle',
            '30 May, 2025',
            '11:00 AM',
            'Auditorium',
            'Show off your voice and steal the spotlight!',
            Icons.mic_rounded,
          ),
        ];
}

class _EventData {
  const _EventData(
    this.title,
    this.date,
    this.time,
    this.venue,
    this.description,
    this.icon,
  );
  final String title;
  final String date;
  final String time;
  final String venue;
  final String description;
  final IconData icon;
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.accent,
    required this.onTap,
  });

  final _EventData event;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
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
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(event.icon, color: accent, size: 54),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${event.date}  |  ${event.time}'),
                    const SizedBox(height: 6),
                    Text(event.venue),
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      style: const TextStyle(color: Color(0xFF55586A)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.bookmark_border_rounded),
            ],
          ),
        ),
      );
}
