import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/notification_api.dart';

final notificationApiProvider = Provider<NotificationApi>((ref) {
  return NotificationApi(ref.watch(apiClientProvider).dio);
});

/// The current user's notification inbox, exposed as a StateNotifier (like
/// myRegistrationsProvider/myCertificatesProvider) so read/delete actions
/// and pull-to-refresh can all trigger a reload without re-reading the
/// whole provider tree. Also drives the unread-count badge on the Home
/// screen's bell icon.
final myNotificationsProvider =
    StateNotifierProvider<MyNotificationsController, AsyncValue<NotificationInboxPage>>((ref) {
  return MyNotificationsController(ref.watch(notificationApiProvider));
});

class MyNotificationsController extends StateNotifier<AsyncValue<NotificationInboxPage>> {
  MyNotificationsController(this._api) : super(const AsyncValue.loading()) {
    refresh();
  }

  final NotificationApi _api;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final page = await _api.fetchMyNotifications();
      state = AsyncValue.data(page);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> markRead(String recipientId) async {
    await _api.markRead(recipientId);
    await refresh();
  }

  Future<void> markAllRead() async {
    await _api.markAllRead();
    await refresh();
  }

  Future<void> delete(String recipientId) async {
    await _api.delete(recipientId);
    await refresh();
  }

  int get unreadCount => state.maybeWhen(data: (page) => page.unreadCount, orElse: () => 0);
}
