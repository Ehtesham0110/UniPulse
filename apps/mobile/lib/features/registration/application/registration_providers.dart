import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/registration_api.dart';
import '../domain/registration_models.dart';

export '../../events/application/event_providers.dart'
    show eventApiProvider, eventDetailProvider, eventListProvider, toggleEventBookmark;

final registrationApiProvider = Provider<RegistrationApi>((ref) {
  return RegistrationApi(ref.watch(apiClientProvider).dio);
});

/// Fetches the QR token for a single registration, for display in My
/// Events. Family-keyed by registrationId.
final registrationQrProvider =
    FutureProvider.family<String, String>((ref, registrationId) async {
  return ref.watch(registrationApiProvider).fetchQrToken(registrationId);
});

/// Holds the current user's registrations. Exposed as a StateNotifier
/// (rather than a plain FutureProvider) so screens can trigger a refresh
/// after a new registration or a cancellation without re-reading the whole
/// provider tree.
final myRegistrationsProvider =
    StateNotifierProvider<MyRegistrationsController, AsyncValue<List<MyRegistration>>>(
        (ref) {
  return MyRegistrationsController(ref.watch(registrationApiProvider));
});

class MyRegistrationsController extends StateNotifier<AsyncValue<List<MyRegistration>>> {
  MyRegistrationsController(this._api) : super(const AsyncValue.loading()) {
    refresh();
  }

  final RegistrationApi _api;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final registrations = await _api.fetchMyRegistrations();
      state = AsyncValue.data(registrations);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> cancel(String registrationId) async {
    await _api.cancel(registrationId);
    await refresh();
  }

  /// True if the current user already has a non-cancelled registration for
  /// this event — used to disable the Register button and explain why.
  bool isRegisteredFor(String eventId) {
    return state.maybeWhen(
      data: (registrations) => registrations
          .any((r) => r.eventId == eventId && !r.isCancelled),
      orElse: () => false,
    );
  }
}
