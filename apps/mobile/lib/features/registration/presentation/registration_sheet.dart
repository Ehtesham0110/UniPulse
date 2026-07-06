import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/widgets/gradient_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../events/domain/event_summary.dart';
import '../../home/application/home_tab_provider.dart';
import '../../payments/application/payment_providers.dart';
import '../../payments/data/payment_api.dart';
import '../../payments/domain/payment_order.dart';
import '../application/registration_providers.dart';
import '../data/registration_api.dart';
import '../domain/registration_models.dart';

void showRegistrationSheet(BuildContext context, {required String eventId}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RegistrationSheet(eventId: eventId),
  );
}

/// Outcome of a single Razorpay checkout attempt, bridging the SDK's
/// event-callback API into something `await`-able from `_submit`.
class _PaymentOutcome {
  const _PaymentOutcome.success({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  })  : isSuccess = true,
        message = null;

  const _PaymentOutcome.failure(this.message)
      : isSuccess = false,
        orderId = '',
        paymentId = '',
        signature = '';

  final bool isSuccess;
  final String orderId;
  final String paymentId;
  final String signature;
  final String? message;
}

class RegistrationSheet extends ConsumerStatefulWidget {
  const RegistrationSheet({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends ConsumerState<RegistrationSheet> {
  final _teamNameController = TextEditingController();
  final List<TextEditingController> _memberNameControllers = [];
  final List<TextEditingController> _memberPhoneControllers = [];

  late final Razorpay _razorpay;
  Completer<_PaymentOutcome>? _paymentCompleter;

  int? _teamSize;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _submitLabel = '';

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _teamNameController.dispose();
    for (final c in _memberNameControllers) {
      c.dispose();
    }
    for (final c in _memberPhoneControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    _paymentCompleter?.complete(
      _PaymentOutcome.success(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      ),
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _paymentCompleter?.complete(
      _PaymentOutcome.failure(
        response.message?.isNotEmpty == true
            ? response.message!
            : 'Payment was cancelled or could not be completed.',
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _paymentCompleter?.complete(
      _PaymentOutcome.failure(
        'Payment was started in ${response.walletName ?? 'an external wallet'}. '
        'Check My Events in a moment to see if it went through, or try again.',
      ),
    );
  }

  void _syncMemberFields(int additionalMembersNeeded) {
    while (_memberNameControllers.length < additionalMembersNeeded) {
      _memberNameControllers.add(TextEditingController());
      _memberPhoneControllers.add(TextEditingController());
    }
    while (_memberNameControllers.length > additionalMembersNeeded) {
      _memberNameControllers.removeLast().dispose();
      _memberPhoneControllers.removeLast().dispose();
    }
  }

  Future<void> _submit(EventSummary event) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _submitLabel = 'Registering…';
    });

    try {
      List<TeamMemberInput>? members;
      if (event.isTeamEvent) {
        if (_teamNameController.text.trim().isEmpty) {
          throw RegistrationApiException('Please enter a team name');
        }
        members = [];
        for (var i = 0; i < _memberNameControllers.length; i++) {
          final name = _memberNameControllers[i].text.trim();
          final phone = _memberPhoneControllers[i].text.trim();
          if (name.isEmpty || phone.isEmpty) {
            throw RegistrationApiException(
                'Please fill in the name and phone number for Member ${i + 2}');
          }
          members.add(TeamMemberInput(fullName: name, phone: phone));
        }
      }

      final newRegistration = await ref.read(registrationApiProvider).register(
            eventId: event.id,
            teamName: event.isTeamEvent ? _teamNameController.text.trim() : null,
            members: members,
          );

      if (newRegistration.needsPayment) {
        await _payAndConfirm(event, newRegistration.registrationId);
      } else {
        await ref.read(myRegistrationsProvider.notifier).refresh();
        _closeWithSuccess(
          message: 'You\'re registered for ${event.title}!',
          goToMyEvents: false,
        );
      }
    } on RegistrationApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _payAndConfirm(EventSummary event, String registrationId) async {
    setState(() => _submitLabel = 'Opening payment…');

    PaymentOrder order;
    try {
      order = await ref.read(paymentApiProvider).createOrder(registrationId);
    } on PaymentApiException catch (error) {
      setState(() => _errorMessage = error.message);
      return;
    }

    final currentUser = ref.read(authControllerProvider).user;
    _paymentCompleter = Completer<_PaymentOutcome>();

    _razorpay.open({
      'key': order.keyId,
      'amount': order.amount * 100, // paise
      'currency': order.currency,
      'order_id': order.orderId,
      'name': 'UniPulse',
      'description': event.title,
      if (currentUser != null)
        'prefill': {'contact': currentUser.phone, 'email': ''},
      'theme': {'color': '#FF6B1A'},
    });

    setState(() => _submitLabel = 'Waiting for payment…');
    final outcome = await _paymentCompleter!.future;

    if (outcome.isSuccess) {
      try {
        await ref.read(paymentApiProvider).verifyPayment(
              orderId: outcome.orderId,
              paymentId: outcome.paymentId,
              signature: outcome.signature,
            );
        await ref.read(myRegistrationsProvider.notifier).refresh();
        _closeWithSuccess(
          message: 'Payment successful! You\'re registered for ${event.title}.',
          goToMyEvents: true,
        );
      } on PaymentApiException catch (error) {
        setState(() => _errorMessage = error.message);
      }
    } else {
      unawaited(ref.read(paymentApiProvider).failPayment(order.paymentId));
      setState(() => _errorMessage = outcome.message);
    }
  }

  void _closeWithSuccess({required String message, required bool goToMyEvents}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (goToMyEvents) {
      ref.read(homeTabIndexProvider.notifier).state = 1; // My Events tab
    }
    Navigator.pop(context);
    if (goToMyEvents) router.go('/home');
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF22A33A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final currentUser = ref.watch(authControllerProvider).user;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: eventAsync.when(
          loading: () => const SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 220,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this event. Please close this and try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF696C7E)),
                ),
              ),
            ),
          ),
          data: (event) {
            _teamSize ??= event.teamMin;
            if (event.isTeamEvent) {
              _syncMemberFields((_teamSize! - 1).clamp(0, 100));
            }

            final registrationsAsync = ref.watch(myRegistrationsProvider);
            final alreadyRegistered = registrationsAsync.maybeWhen(
              data: (regs) => regs.any((r) => r.eventId == event.id && !r.isCancelled),
              orElse: () => false,
            );
            final canRegister =
                event.isRegistrationOpen && !event.isFull && !alreadyRegistered;

            return ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D8E0),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Register for ${event.title}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (event.isTeamEvent) ...[
                  const Text(
                    '1. Select Team Size',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var size = event.teamMin; size <= event.teamMax; size++)
                        _SizeOption(
                          label: '$size Members',
                          selected: _teamSize == size,
                          onTap: () => setState(() {
                            _teamSize = size;
                            _syncMemberFields(size - 1);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '2. Team Details',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text('Team Name'),
                  const SizedBox(height: 8),
                  _Field.editable(hint: 'Enter your team name', controller: _teamNameController),
                  const SizedBox(height: 16),
                  const Text('Member 1 (Team Leader) — You'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(currentUser?.fullName ?? 'You'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Field(currentUser?.phone ?? ''),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _memberNameControllers.length; i++) ...[
                    Text('Member ${i + 2}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _Field.editable(
                            hint: 'Full Name',
                            controller: _memberNameControllers[i],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Field.editable(
                            hint: '+91  Enter Phone Number',
                            controller: _memberPhoneControllers[i],
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ] else ...[
                  const Text(
                    'You\'re registering as an individual participant.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currentUser?.fullName ?? ''} · ${currentUser?.phone ?? ''}',
                    style: const TextStyle(color: Color(0xFF696C7E)),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Entry Fee',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        color: event.paid ? const Color(0xFFFF6B1A) : const Color(0xFF22A33A),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          event.paid
                              ? 'You\'ll be asked to pay securely via Razorpay.'
                              : 'Free Entry\nNo payment required for this event.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        event.paid ? '₹${event.price}' : '₹0',
                        style: TextStyle(
                          fontSize: 24,
                          color: event.paid ? const Color(0xFFFF6B1A) : const Color(0xFF169D3A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAEA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFD32F2F)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!canRegister && _errorMessage == null) ...[
                  const SizedBox(height: 16),
                  Text(
                    alreadyRegistered
                        ? 'You\'re already registered for this event.'
                        : event.isFull
                            ? 'This event has reached its maximum number of participants.'
                            : 'Registration is not currently open for this event.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF9295A4)),
                  ),
                ],
                const SizedBox(height: 24),
                GradientButton(
                  label: _isSubmitting
                      ? _submitLabel
                      : (event.paid ? 'Pay ₹${event.price} & Register' : 'Confirm Registration'),
                  icon: Icons.arrow_forward,
                  onPressed: (_isSubmitting || !canRegister) ? () {} : () => _submit(event),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            margin: const EdgeInsets.only(right: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF6DF) : Colors.white,
              border: Border.all(
                color: selected ? const Color(0xFFFFAA00) : const Color(0xFFE3E3EA),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field(this.value)
      : controller = null,
        hint = null,
        keyboardType = null;

  const _Field.editable({
    required this.hint,
    required this.controller,
    this.keyboardType,
  }) : value = null;

  final String? value;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3E3EA)),
        borderRadius: BorderRadius.circular(12),
        color: controller == null ? const Color(0xFFF7F7FA) : null,
      ),
      child: controller != null
          ? TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF9A9DAA)),
                border: InputBorder.none,
                isDense: true,
              ),
            )
          : Text(value ?? '', style: const TextStyle(color: Color(0xFF4C4F61))),
    );
  }
}
