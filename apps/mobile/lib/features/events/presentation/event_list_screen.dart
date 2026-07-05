import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatting.dart';
import '../application/event_providers.dart';
import '../data/event_api.dart';
import '../domain/event_summary.dart';

enum _TimeFilter { all, upcoming, past }

class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({required this.category, super.key});

  final String category;

  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  _TimeFilter _timeFilter = _TimeFilter.all;

  bool get isTech =>
      widget.category.toLowerCase().contains('tech') &&
      !widget.category.toLowerCase().contains('non');

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _searchQuery = value);
    });
  }

  List<EventSummary> _applyTimeFilter(List<EventSummary> events) {
    final now = DateTime.now();
    switch (_timeFilter) {
      case _TimeFilter.upcoming:
        return events.where((e) => e.eventDate == null || !e.eventDate!.isBefore(now)).toList();
      case _TimeFilter.past:
        return events.where((e) => e.eventDate != null && e.eventDate!.isBefore(now)).toList();
      case _TimeFilter.all:
        return events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = isTech ? const Color(0xFF8A42E8) : const Color(0xFFFFAA00);
    final bg = isTech ? const Color(0xFFF1E8FF) : const Color(0xFFFFF4CF);

    final eventsAsync = ref.watch(
      eventListProvider(EventListQuery(category: widget.category, search: _searchQuery)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.category} Events',
          style: TextStyle(color: accent, fontWeight: FontWeight.w800),
        ),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(
                  isTech ? Icons.laptop_mac_rounded : Icons.emoji_events_rounded,
                  color: accent,
                  size: 74,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search ${widget.category} events…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final filter in _TimeFilter.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _timeFilter = filter),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _timeFilter == filter ? accent : Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12),
                        ],
                      ),
                      child: Text(
                        switch (filter) {
                          _TimeFilter.all => 'All',
                          _TimeFilter.upcoming => 'Upcoming',
                          _TimeFilter.past => 'Past',
                        },
                        style: TextStyle(
                          color: _timeFilter == filter ? Colors.white : const Color(0xFF222433),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          eventsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Color(0xFF9295A4)),
                  const SizedBox(height: 12),
                  Text(
                    error is EventApiException ? error.message : 'Could not load events.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF696C7E)),
                  ),
                ],
              ),
            ),
            data: (events) {
              final filtered = _applyTimeFilter(events);
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50),
                  child: Column(
                    children: [
                      const Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFF9295A4)),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No events match "$_searchQuery"'
                            : 'No ${widget.category.toLowerCase()} events right now',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF696C7E), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final event in filtered) ...[
                    _EventCard(
                      event: event,
                      accent: accent,
                      onTap: () => context.push('/event/${event.id}'),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event, required this.accent, required this.onTap});

  final EventSummary event;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLabel = event.eventDate != null ? formatEventDate(event.eventDate!) : 'Date TBA';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14),
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
              child: Icon(
                event.isTech ? Icons.laptop_mac_rounded : Icons.emoji_events_rounded,
                color: accent,
                size: 54,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('$dateLabel  |  ${event.startTime.isEmpty ? 'TBA' : event.startTime}'),
                  const SizedBox(height: 6),
                  Text(event.venue),
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF55586A)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                event.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: event.isBookmarked ? accent : null,
              ),
              onPressed: () => toggleEventBookmark(ref, event.id),
            ),
          ],
        ),
      ),
    );
  }
}
