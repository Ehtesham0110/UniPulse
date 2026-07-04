import 'package:flutter/material.dart';

import '../../../core/widgets/gradient_button.dart';

void showRegistrationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const RegistrationSheet(),
  );
}

class RegistrationSheet extends StatelessWidget {
  const RegistrationSheet({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: ListView(
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
                const Expanded(
                  child: Text(
                    'Register for Treasure Hunt',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '1. Select Team Size',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                _SizeOption('2 Members', true),
                _SizeOption('3 Members', false),
                _SizeOption('4 Members', false),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '2. Team Members',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (var i = 1; i <= 4; i++) ...[
              Text(
                i == 1
                    ? 'Member 1 (Team Leader)'
                    : i > 2
                        ? 'Member $i (Optional)'
                        : 'Member $i',
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Expanded(child: _Field('Full Name')),
                  SizedBox(width: 10),
                  Expanded(child: _Field('+91  Enter Phone Number')),
                ],
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            const Text(
              '3. Entry Fee',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFFE5E5EA)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: Color(0xFF22A33A),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Free Entry\nNo payment required for this event.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '₹0',
                    style: TextStyle(
                      fontSize: 24,
                      color: Color(0xFF169D3A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Done',
              icon: Icons.arrow_forward,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeOption extends StatelessWidget {
  const _SizeOption(this.label, this.selected);
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 52,
          margin: const EdgeInsets.only(right: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF6DF) : Colors.white,
            border: Border.all(
              color:
                  selected ? const Color(0xFFFFAA00) : const Color(0xFFE3E3EA),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field(this.hint);
  final String hint;
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFE3E3EA)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(hint, style: const TextStyle(color: Color(0xFF9A9DAA))),
      );
}
