import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/admin_api.dart';
import '../domain/admin_member.dart';

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(apiClientProvider).dio);
});

final adminListProvider = FutureProvider<List<AdminMember>>((ref) async {
  return ref.watch(adminApiProvider).listAdmins();
});
