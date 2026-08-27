import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../core/widgets/campus_tree_footer.dart';
import '../application/event_providers.dart';
import '../data/event_api.dart';
import '../domain/event_summary.dart';
import '../utils/calendar_export_utils.dart';

class EventCalendarScreen extends ConsumerStatefulWidget {
  const EventCalendarScreen({super.key});

  @override
  ConsumerState<EventCalendarScreen> createState() => _EventCalendarScreenState();
}

class _EventCalendarScreenState extends ConsumerState<EventCalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final endOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0, 23, 59, 59);

    final query = EventListQuery(
      startDate: startOfMonth.toIso8601String(),
      endDate: endOfMonth.toIso8601String(),
    );

    final eventsAsync = ref.watch(eventListProvider(query));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // App bar & Month selector
                _CalendarHeader(
                  focusedMonth: _focusedMonth,
                  onPrevMonth: _previousMonth,
                  onNextMonth: _nextMonth,
                  onTodayPressed: () {
                    final now = DateTime.now();
                    setState(() {
                      _focusedMonth = DateTime(now.year, now.month, 1);
                      _selectedDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(eventListProvider(query));
                    },
                    child: eventsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => _CalendarErrorView(
                        onRetry: () => ref.invalidate(eventListProvider(query)),
                      ),
                      data: (monthEvents) {
                        final eventsByDay = _groupEventsByDay(monthEvents);
                        final selectedDayEvents = _getEventsForDay(_selectedDate, eventsByDay);

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                          children: [
                            // Days of week header
                            const _WeekdayHeader(),
                            const SizedBox(height: 8),
                            // Monthly Grid
                            _CalendarGrid(
                              focusedMonth: _focusedMonth,
                              selectedDate: _selectedDate,
                              eventsByDay: eventsByDay,
                              onDateSelected: _onDateSelected,
                            ),
                            const SizedBox(height: 24),
                            // Selected Date Events Header
                            _SelectedDateHeader(selectedDate: _selectedDate),
                            const SizedBox(height: 12),
                            // Events List or Empty State
                            if (selectedDayEvents.isEmpty)
                              _EmptyDayView(selectedDate: _selectedDate)
                            else
                              for (final event in selectedDayEvents) ...[
                                _CalendarEventCard(event: event),
                                const SizedBox(height: 12),
                              ],
                          ],
                        );
                      },
                    ),
                  ),
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
      ),
    );
  }

  Map<int, List<EventSummary>> _groupEventsByDay(List<EventSummary> events) {
    final map = <int, List<EventSummary>>{};
    for (final event in events) {
      if (event.eventDate != null) {
        final day = event.eventDate!.day;
        map.putIfAbsent(day, () => []).add(event);
      }
    }
    return map;
  }

  List<EventSummary> _getEventsForDay(DateTime date, Map<int, List<EventSummary>> map) {
    if (date.year == _focusedMonth.year && date.month == _focusedMonth.month) {
      return map[date.day] ?? [];
    }
    return [];
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.focusedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onTodayPressed,
  });

  final DateTime focusedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTodayPressed;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final monthName = _months[focusedMonth.month - 1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Text(
            '$monthName ${focusedMonth.year}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          IconButton(
            onPressed: onPrevMonth,
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
          ),
          IconButton(
            onPressed: onNextMonth,
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
          ),
          TextButton(
            onPressed: onTodayPressed,
            child: const Text(
              'Today',
              style: TextStyle(color: Color(0xFFFF4F16), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final day in _weekdays)
          Expanded(
            child: Center(
              child: Text(
                day,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF8C8F9E),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.eventsByDay,
    required this.onDateSelected,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<int, List<EventSummary>> eventsByDay;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final leadingPadding = firstDayOfMonth.weekday % 7; // Sunday = 0

    final totalCells = leadingPadding + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: [
        for (int row = 0; row < rowCount; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                for (int col = 0; col < 7; col++) ...[
                  Expanded(
                    child: _buildDayCell(
                      context,
                      dayNumber: row * 7 + col - leadingPadding + 1,
                      daysInMonth: daysInMonth,
                      now: now,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDayCell(
    BuildContext context, {
    required int dayNumber,
    required int daysInMonth,
    required DateTime now,
  }) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 52);
    }

    final cellDate = DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
    final isSelected = selectedDate.year == cellDate.year &&
        selectedDate.month == cellDate.month &&
        selectedDate.day == cellDate.day;
    final isToday = now.year == cellDate.year &&
        now.month == cellDate.month &&
        now.day == cellDate.day;

    final events = eventsByDay[dayNumber] ?? [];
    final hasTech = events.any((e) => e.isTech);
    final hasNonTech = events.any((e) => !e.isTech);

    Color bg = Colors.transparent;
    Color textColor = const Color(0xFF1F2130);
    Border? border;

    if (isSelected) {
      bg = const Color(0xFFFF4F16);
      textColor = Colors.white;
    } else if (isToday) {
      bg = const Color(0xFFE7F6E6);
      textColor = const Color(0xFF24A546);
      border = Border.all(color: const Color(0xFF24A546), width: 1.5);
    }

    return GestureDetector(
      onTap: () => onDateSelected(cellDate),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: border,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                color: textColor,
              ),
            ),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasTech)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.white : const Color(0xFF8A42E8),
                      ),
                    ),
                  if (hasNonTech)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.white : const Color(0xFFFF851A),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedDateHeader extends StatelessWidget {
  const _SelectedDateHeader({required this.selectedDate});
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final dateStr = formatEventDate(selectedDate);
    final dayStr = formatWeekday(selectedDate);

    return Row(
      children: [
        Icon(Icons.event_rounded, size: 20, color: const Color(0xFFFF4F16)),
        const SizedBox(width: 8),
        Text(
          '$dayStr, $dateStr',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _EmptyDayView extends StatelessWidget {
  const _EmptyDayView({required this.selectedDate});
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEEF2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, size: 42, color: Color(0xFF9E9EA5)),
          const SizedBox(height: 12),
          const Text(
            'No events scheduled for this date',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select a date with category dots to view upcoming campus events.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF696C7E)),
          ),
        ],
      ),
    );
  }
}

class _CalendarEventCard extends ConsumerWidget {
  const _CalendarEventCard({required this.event});
  final EventSummary event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTech = event.isTech;

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 72,
              decoration: BoxDecoration(
                color: isTech ? const Color(0xFFF1E8FF) : const Color(0xFFFFF0CE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  isTech ? Icons.laptop_mac_rounded : Icons.emoji_events_rounded,
                  color: isTech ? const Color(0xFF8A42E8) : const Color(0xFFFF851A),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTech ? const Color(0xFFE8D8FF) : const Color(0xFFFFE8A8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isTech ? const Color(0xFF6B26C2) : const Color(0xFFC75D00),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (event.paid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F6E6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₹${event.price}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF24A546),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.startTime.isEmpty ? 'TBA' : event.startTime}  •  ${event.venue}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF65687A)),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(
                    event.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: event.isBookmarked ? const Color(0xFFFF6B1A) : null,
                  ),
                  onPressed: () => toggleEventBookmark(ref, event.id),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar_rounded, size: 20, color: Color(0xFFFF4F16)),
                  onPressed: () => CalendarExportUtils.showExportBottomSheet(context, event),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarErrorView extends StatelessWidget {
  const _CalendarErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF9E9EA5)),
            const SizedBox(height: 12),
            const Text(
              'Could not load calendar events',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF65687A)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
