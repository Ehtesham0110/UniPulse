import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/event_api.dart';
import '../domain/event_summary.dart';

final eventApiProvider = Provider<EventApi>((ref) {
  return EventApi(ref.watch(apiClientProvider).dio);
});

/// Fetches a single event's full details — used by the event detail screen
/// and the registration sheet.
final eventDetailProvider =
    FutureProvider.family<EventSummary, String>((ref, eventId) async {
  return ref.watch(eventApiProvider).getEvent(eventId);
});

/// Fetches a filtered/searched list of events (category + free-text
/// search), used by the Home screen highlights and the Event List screen.
final eventListProvider =
    FutureProvider.family<List<EventSummary>, EventListQuery>((ref, query) async {
  return ref.watch(eventApiProvider).listEvents(query);
});

/// Toggles the bookmark on an event and invalidates every cache that could
/// be showing its bookmark state, so the UI updates everywhere at once
/// (event list cards, home highlights, and the detail screen).
Future<void> toggleEventBookmark(WidgetRef ref, String eventId) async {
  await ref.read(eventApiProvider).toggleBookmark(eventId);
  ref.invalidate(eventDetailProvider(eventId));
  ref.invalidate(eventListProvider);
}
