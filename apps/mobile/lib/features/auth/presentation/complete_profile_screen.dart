import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/gradient_button.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

const _branches = ['ECS', 'CS', 'IT', 'AIML', 'MECH', 'EXTC'];

/// Shown when a phone number verified via OTP doesn't yet have a backend
/// account — we already have a verified identity, we just need the
/// student's academic details to finish creating the profile.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _fullNameController = TextEditingController();
  final _rollNumberController = TextEditingController();
  String _branch = _branches.first;
  int _year = 1;

  @override
  void dispose() {
    _fullNameController.dispose();
    _rollNumberController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_fullNameController.text.trim().isEmpty ||
        _rollNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    ref.read(authControllerProvider.notifier).completeSignup(
          PendingSignupDetails(
            fullName: _fullNameController.text.trim(),
            rollNumber: _rollNumberController.text.trim(),
            branch: _branch,
            year: _year,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      } else if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    final isLoading = ref.watch(authControllerProvider).status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "You're almost there!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'We just need a few academic details to set up your account.',
            style: TextStyle(color: Color(0xFF696C7E)),
          ),
          const SizedBox(height: 24),
          const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              hintText: 'Enter your full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Roll Number', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _rollNumberController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'e.g. VU3F2526129',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Branch', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _branches
                .map((branch) => ChoiceChip(
                      label: Text(branch),
                      selected: _branch == branch,
                      onSelected: (_) => setState(() => _branch = branch),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Year', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [1, 2, 3, 4]
                .map((year) => ChoiceChip(
                      label: Text('Year $year'),
                      selected: _year == year,
                      onSelected: (_) => setState(() => _year = year),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
          GradientButton(
            label: isLoading ? 'Please wait…' : 'Create Account',
            icon: Icons.arrow_forward,
            onPressed: isLoading ? () {} : _submit,
          ),
        ],
      ),
    );
  }
}
