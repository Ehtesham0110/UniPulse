import 'package:flutter/material.dart';

import '../../../core/widgets/gradient_button.dart';
import '../../registration/presentation/registration_sheet.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFAA00);
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              Container(
                height: 360,
                padding: const EdgeInsets.fromLTRB(24, 54, 24, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE8A8),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.bookmark_border),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.share_rounded),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Chip(
                      label: Text('Non Tech Event'),
                      backgroundColor: Color(0xFFFFD978),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Treasure Hunt',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Find clues, solve puzzles and be the ultimate treasure finder!',
                      style: TextStyle(fontSize: 17, color: Color(0xFF4C4F61)),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _MetaGrid(accent: accent),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'About the Event',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Are you ready for an adventure? Decode the clues, solve challenging puzzles and race against time to find the hidden treasure.',
                    ),
                    SizedBox(height: 26),
                    Text(
                      'Event Highlights',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 14),
                    _HighlightRow(),
                    SizedBox(height: 26),
                    Text(
                      'Schedule',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 14),
                    _Schedule(),
                    SizedBox(height: 26),
                    Text(
                      'Gallery',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 14),
                    _Gallery(),
                    SizedBox(height: 26),
                    _OrganizerCard(),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Free Entry\nLimited Spots!',
                      style: TextStyle(
                        color: Color(0xFF169D3A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GradientButton(
                      label: 'Register Now',
                      icon: Icons.arrow_forward,
                      onPressed: () => showRegistrationSheet(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08), blurRadius: 22),
          ],
        ),
        child: Row(
          children: const [
            _MetaItem(Icons.calendar_month, 'Date', '25 May, 2025', 'Sunday'),
            _MetaItem(Icons.schedule, 'Time', '10:00 AM', 'Onwards'),
            _MetaItem(
              Icons.location_on_outlined,
              'Venue',
              'Main Campus',
              'Starts at Plaza',
            ),
            _MetaItem(
              Icons.groups_rounded,
              'Team Size',
              '2 - 4 Members',
              'Per Team',
            ),
          ],
        ),
      );
}

class _MetaItem extends StatelessWidget {
  const _MetaItem(this.icon, this.label, this.value, this.caption);
  final IconData icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: Color(0xFFFFAA00)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF626577), fontSize: 12),
            ),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF626577), fontSize: 11),
            ),
          ],
        ),
      );
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow();
  @override
  Widget build(BuildContext context) => Row(
        children: [
          'Mind Bending\nPuzzles',
          'Team\nCollaboration',
          'Exciting\nRewards',
          'Time Bound\nChallenge',
        ]
            .map(
              (text) => Expanded(
                child: Container(
                  height: 78,
                  margin: const EdgeInsets.only(right: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
}

class _Schedule extends StatelessWidget {
  const _Schedule();
  @override
  Widget build(BuildContext context) => Column(
        children: const [
          _ScheduleItem('10:00 AM', 'Registration & Briefing'),
          _ScheduleItem('10:30 AM', 'Clue 1 Released'),
          _ScheduleItem('11:00 AM', 'Clue 2 Released'),
          _ScheduleItem('01:00 PM', 'Final Treasure Location Reveal'),
        ],
      );
}

class _ScheduleItem extends StatelessWidget {
  const _ScheduleItem(this.time, this.title);
  final String time;
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            const Icon(Icons.circle, color: Color(0xFFFFAA00), size: 12),
            const SizedBox(width: 16),
            SizedBox(
              width: 80,
              child: Text(
                time,
                style: const TextStyle(
                  color: Color(0xFFFF6B1A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class _Gallery extends StatelessWidget {
  const _Gallery();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) => Container(
            width: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2CC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.image_rounded,
              color: Color(0xFFFFAA00),
              size: 46,
            ),
          ),
        ),
      );
}

class _OrganizerCard extends StatelessWidget {
  const _OrganizerCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFEDEDF2)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: const [
            CircleAvatar(
              backgroundColor: Colors.black,
              child: Text('UP', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'UniPulse Club\nEmpowering students. Creating memories.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.chat_bubble_outline_rounded),
          ],
        ),
      );
}
