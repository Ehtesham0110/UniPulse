import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatting.dart';
import '../../registration/application/registration_providers.dart';
import '../../registration/data/registration_api.dart';
import '../../registration/domain/registration_models.dart';

class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationsAsync = ref.watch(myRegistrationsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(myRegistrationsProvider.notifier).refresh(),
        child: registrationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.error_outline, size: 56, color: Color(0xFF9295A4)),
              const SizedBox(height: 12),
              const Text(
                'Could not load your events',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                error is RegistrationApiException
                    ? error.message
                    : 'Pull down to try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF696C7E)),
              ),
            ],
          ),
          data: (registrations) {
            final active = registrations.where((r) => !r.isCancelled && !r.isPast).toList();
            final past = registrations.where((r) => !r.isCancelled && r.isPast).toList();

            if (registrations.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      'No registrations yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Events you register for will show up here.',
                      style: TextStyle(color: Color(0xFF696C7E)),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Center(
                  child: Text(
                    'My Events',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 28),
                if (active.isNotEmpty) ...[
                  const Text(
                    'Upcoming Events',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  for (final registration in active) ...[
                    _MyEventCard(registration: registration),
                    const SizedBox(height: 14),
                  ],
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Past Events',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  for (final registration in past) ...[
                    _MyEventCard(registration: registration, past: true),
                    const SizedBox(height: 14),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MyEventCard extends ConsumerWidget {
  const _MyEventCard({required this.registration, this.past = false});

  final MyRegistration registration;
  final bool past;

  Color get _statusColor {
    switch (registration.status) {
      case 'Confirmed':
        return const Color(0xFF22A33A);
      case 'Pending Payment':
        return const Color(0xFFFF6B1A);
      case 'Attended':
      case 'Completed':
        return const Color(0xFF3A7BFF);
      default:
        return const Color(0xFF696C7E);
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel registration?'),
        content: Text('Are you sure you want to cancel your registration for "${registration.eventTitle}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(myRegistrationsProvider.notifier).cancel(registration.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Registration cancelled')));
      }
    } on RegistrationApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTech = registration.eventCategory.toLowerCase() == 'tech';
    final dateLabel =
        registration.eventDate != null ? formatEventDate(registration.eventDate!) : 'Date TBA';
    final canCancel = !past && registration.status == 'Confirmed';

    return GestureDetector(
      onTap: () => context.push('/event/${registration.eventId}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: isTech ? const Color(0xFFE8D8FF) : const Color(0xFFFFE8A8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isTech ? Icons.laptop_mac : Icons.emoji_events,
                color: isTech ? const Color(0xFF8A42E8) : const Color(0xFFFFAA00),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    registration.eventCategory,
                    style: const TextStyle(color: Color(0xFFFF6B1A), fontWeight: FontWeight.w700),
                  ),
                  Text(
                    registration.eventTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text('$dateLabel  |  ${registration.eventVenue}'),
                  const SizedBox(height: 8),
                  Text(
                    registration.status,
                    style: TextStyle(color: _statusColor, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (canCancel)
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF9295A4)),
                tooltip: 'Cancel registration',
                onPressed: () => _confirmCancel(context, ref),
              )
            else
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
