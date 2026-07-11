import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/certificate_api.dart';
import '../domain/earned_certificate.dart';

final certificateApiProvider = Provider<CertificateApi>((ref) {
  return CertificateApi(ref.watch(apiClientProvider).dio);
});

/// The current user's earned certificates. A StateNotifier (like
/// myRegistrationsProvider) so the admin generate/bulk-generate flows —
/// and the student pulling to refresh — can trigger a reload without
/// re-reading the whole provider tree.
final myCertificatesProvider =
    StateNotifierProvider<MyCertificatesController, AsyncValue<List<EarnedCertificate>>>((ref) {
  return MyCertificatesController(ref.watch(certificateApiProvider));
});

class MyCertificatesController extends StateNotifier<AsyncValue<List<EarnedCertificate>>> {
  MyCertificatesController(this._api) : super(const AsyncValue.loading()) {
    refresh();
  }

  final CertificateApi _api;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final certificates = await _api.fetchMyCertificates();
      state = AsyncValue.data(certificates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
