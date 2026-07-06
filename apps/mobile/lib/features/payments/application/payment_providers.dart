import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/payment_api.dart';

final paymentApiProvider = Provider<PaymentApi>((ref) {
  return PaymentApi(ref.watch(apiClientProvider).dio);
});
