import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/event_summary.dart';

class CalendarExportUtils {
  static String formatGoogleCalendarUrl(EventSummary event) {
    final title = Uri.encodeComponent(event.title);
    final details = Uri.encodeComponent('${event.description}\n\nCategory: ${event.category}');
    final location = Uri.encodeComponent(event.venue);

    final startDate = event.eventDate ?? DateTime.now();
    final startDateTime = _parseDateTimeWithTime(startDate, event.startTime);
    final endDateTime = _parseDateTimeWithTime(startDate, event.endTime.isNotEmpty ? event.endTime : event.startTime).add(
      event.endTime.isEmpty ? const Duration(hours: 2) : Duration.zero,
    );

    final startStr = _toIsoUtcString(startDateTime);
    final endStr = _toIsoUtcString(endDateTime);

    return 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$startStr/$endStr&details=$details&location=$location';
  }

  static String formatIcsDataUrl(EventSummary event) {
    final startDate = event.eventDate ?? DateTime.now();
    final startDateTime = _parseDateTimeWithTime(startDate, event.startTime);
    final endDateTime = _parseDateTimeWithTime(startDate, event.endTime.isNotEmpty ? event.endTime : event.startTime).add(
      event.endTime.isEmpty ? const Duration(hours: 2) : Duration.zero,
    );

    final startStr = _toIsoUtcString(startDateTime);
    final endStr = _toIsoUtcString(endDateTime);

    final cs = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//UniPulse//Campus Events//EN',
      'BEGIN:VEVENT',
      'SUMMARY:${event.title}',
      'DESCRIPTION:${event.description.replaceAll('\n', ' ')}',
      'LOCATION:${event.venue}',
      'DTSTART:$startStr',
      'DTEND:$endStr',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    return 'data:text/calendar;charset=utf8,${Uri.encodeComponent(cs)}';
  }

  static Future<bool> launchGoogleCalendar(EventSummary event) async {
    final url = Uri.parse(formatGoogleCalendarUrl(event));
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  static Future<bool> launchAppleCalendar(EventSummary event) async {
    final url = Uri.parse(formatIcsDataUrl(event));
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      return await launchGoogleCalendar(event);
    }
  }

  static void showExportBottomSheet(BuildContext context, EventSummary event) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Color(0xFFFF4F16)),
                    const SizedBox(width: 10),
                    const Text(
                      'Export to Calendar',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Add "${event.title}" to your personal calendar',
                  style: const TextStyle(color: Color(0xFF65687A)),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F1FF),
                    child: Icon(Icons.g_mobiledata_rounded, color: Color(0xFF1A73E8), size: 28),
                  ),
                  title: const Text(
                    'Google Calendar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Opens in Google Calendar web/app'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    launchGoogleCalendar(event);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF2F2F7),
                    child: Icon(Icons.apple_rounded, color: Colors.black, size: 24),
                  ),
                  title: const Text(
                    'Apple Calendar / iCal',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Downloads .ics calendar file'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    launchAppleCalendar(event);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static DateTime _parseDateTimeWithTime(DateTime date, String timeStr) {
    if (timeStr.isEmpty) return date;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final numbers = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = numbers.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0]);
        int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    } catch (_) {}
    return date;
  }

  static String _toIsoUtcString(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final min = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$min${s}Z';
  }
}
