import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../registration/application/registration_providers.dart';
import '../../registration/presentation/registration_sheet.dart';
import '../domain/event_summary.dart';
import '../utils/calendar_export_utils.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onBack: () => Navigator.maybePop(context),
        ),
        data: (event) => _EventDetailBody(event: event),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Color(0xFF9295A4)),
              const SizedBox(height: 16),
              const Text(
                'We couldn\'t load this event',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'It may no longer exist, or there was a problem reaching the server.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF696C7E)),
              ),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onBack, child: const Text('Go Back')),
            ],
          ),
        ),
      );
}

class _EventDetailBody extends ConsumerWidget {
  const _EventDetailBody({required this.event});
  final EventSummary event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const accent = Color(0xFFFFAA00);
    final isTech = event.category.toLowerCase() == 'tech';
    final dateLabel = event.eventDate != null ? formatEventDate(event.eventDate!) : 'Date TBA';
    final dayLabel = event.eventDate != null ? formatWeekday(event.eventDate!) : '';

    final registrationsAsync = ref.watch(myRegistrationsProvider);
    final alreadyRegistered = registrationsAsync.maybeWhen(
      data: (regs) => regs.any((r) => r.eventId == event.id && !r.isCancelled),
      orElse: () => false,
    );
    final canRegister = event.isRegistrationOpen && !event.isFull && !alreadyRegistered;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            Container(
              height: 320,
              padding: const EdgeInsets.fromLTRB(24, 54, 24, 24),
              decoration: BoxDecoration(
                color: isTech ? const Color(0xFFE8D8FF) : const Color(0xFFFFE8A8),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => CalendarExportUtils.showExportBottomSheet(context, event),
                        icon: const Icon(Icons.edit_calendar_rounded),
                        tooltip: 'Export to Calendar',
                      ),
                      IconButton(
                        onPressed: () => toggleEventBookmark(ref, event.id),
                        icon: Icon(
                          event.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Chip(
                    label: Text('${event.category} Event'),
                    backgroundColor: isTech ? const Color(0xFFD8BBFF) : const Color(0xFFFFD978),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF4C4F61)),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _MetaGrid(
                  accent: accent,
                  dateLabel: dateLabel,
                  dayLabel: dayLabel,
                  timeLabel: event.startTime.isEmpty ? 'TBA' : event.startTime,
                  venue: event.venue,
                  teamSizeLabel: event.isTeamEvent
                      ? '${event.teamMin} - ${event.teamMax} Members'
                      : 'Individual',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About the Event',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(event.description.isEmpty ? 'No description provided yet.' : event.description),
                  if (event.highlights.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    const Text(
                      'Highlights',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    for (final highlight in event.highlights)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFAA00)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(highlight)),
                          ],
                        ),
                      ),
                  ],
                  if (event.schedule.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'Schedule',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    for (final item in event.schedule)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 74,
                              child: Text(
                                item.time,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFF6B1A)),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (item.description != null && item.description!.isNotEmpty)
                                    Text(
                                      item.description!,
                                      style: const TextStyle(color: Color(0xFF696C7E)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (event.galleryUrls.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'Gallery',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: event.galleryUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            event.galleryUrls[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 100,
                              height: 100,
                              color: const Color(0xFFF3F3F7),
                              child: const Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (event.organizer.hasInfo) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'Organizer',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14),
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFFFEAD5),
                            child: Icon(Icons.person, color: Color(0xFFFF6B1A)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (event.organizer.name != null)
                                  Text(
                                    event.organizer.name!,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                if (event.organizer.contactNumber != null)
                                  Text(
                                    event.organizer.contactNumber!,
                                    style: const TextStyle(color: Color(0xFF696C7E)),
                                  ),
                                if (event.organizer.email != null)
                                  Text(
                                    event.organizer.email!,
                                    style: const TextStyle(color: Color(0xFF696C7E)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  if (!canRegister)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF696C7E)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              alreadyRegistered
                                  ? 'You\'re already registered for this event.'
                                  : event.isFull
                                      ? 'This event is full.'
                                      : 'Registration isn\'t open for this event right now.',
                              style: const TextStyle(fontWeight: FontWeight.w600),
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
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    event.paid ? '₹${event.price}\nEntry Fee' : 'Free Entry\n${event.isFull ? 'Full' : 'Open Now'}',
                    style: TextStyle(
                      color: event.paid ? const Color(0xFFFF6B1A) : const Color(0xFF169D3A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: GradientButton(
                    label: alreadyRegistered ? 'Registered' : 'Register Now',
                    icon: Icons.arrow_forward,
                    onPressed: canRegister
                        ? () => showRegistrationSheet(context, eventId: event.id)
                        : () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({
    required this.accent,
    required this.dateLabel,
    required this.dayLabel,
    required this.timeLabel,
    required this.venue,
    required this.teamSizeLabel,
  });
  final Color accent;
  final String dateLabel;
  final String dayLabel;
  final String timeLabel;
  final String venue;
  final String teamSizeLabel;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 22),
          ],
        ),
        child: Row(
          children: [
            _MetaItem(Icons.calendar_month, 'Date', dateLabel, dayLabel),
            _MetaItem(Icons.schedule, 'Time', timeLabel, 'Onwards'),
            _MetaItem(Icons.location_on_outlined, 'Venue', venue, ''),
            _MetaItem(Icons.groups_rounded, 'Team Size', teamSizeLabel, 'Per Team'),
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
            Icon(icon, color: const Color(0xFFFFAA00)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Color(0xFF626577), fontSize: 12)),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            if (caption.isNotEmpty)
              Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF626577), fontSize: 11),
              ),
          ],
        ),
      );
}