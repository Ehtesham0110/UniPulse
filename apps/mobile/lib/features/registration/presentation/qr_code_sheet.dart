import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../application/registration_providers.dart';
import '../domain/registration_models.dart';

void showRegistrationQrSheet(BuildContext context, MyRegistration registration) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QrSheet(registration: registration),
  );
}

class _QrSheet extends ConsumerWidget {
  const _QrSheet({required this.registration});

  final MyRegistration registration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qrAsync = ref.watch(registrationQrProvider(registration.id));

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD8D8E0),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            registration.eventTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            registration.status == 'Attended'
                ? 'Checked in — show this if asked'
                : 'Show this QR code at the event entrance',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF696C7E)),
          ),
          const SizedBox(height: 28),
          qrAsync.when(
            loading: () => const SizedBox(
              height: 240,
              width: 240,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SizedBox(
              height: 240,
              width: 240,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not load your QR code. Please try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF696C7E)),
                  ),
                ),
              ),
            ),
            data: (qrToken) => Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E5EA)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: qrToken,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                registration.status == 'Attended' ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: registration.status == 'Attended'
                    ? const Color(0xFF22A33A)
                    : const Color(0xFF9295A4),
              ),
              const SizedBox(width: 6),
              Text(
                registration.status == 'Attended' ? 'Already checked in' : 'Not checked in yet',
                style: const TextStyle(color: Color(0xFF696C7E)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
