import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/gradient_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../events/domain/event_summary.dart';
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

  int? _teamSize;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _teamNameController.dispose();
    for (final c in _memberNameControllers) {
      c.dispose();
    }
    for (final c in _memberPhoneControllers) {
      c.dispose();
    }
    super.dispose();
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

      await ref.read(registrationApiProvider).register(
            eventId: event.id,
            teamName: event.isTeamEvent ? _teamNameController.text.trim() : null,
            members: members,
          );

      await ref.read(myRegistrationsProvider.notifier).refresh();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You\'re registered for ${event.title}!'),
          backgroundColor: const Color(0xFF22A33A),
        ),
      );
    } on RegistrationApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                              ? 'Payment required to confirm your spot.'
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
                if (event.paid) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Online payment isn\'t available yet — this milestone covers '
                    'registration only. Your spot will show as "Pending Payment" '
                    'until payments are wired up in a future update.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9295A4)),
                  ),
                ],
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
                      ? 'Registering…'
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
