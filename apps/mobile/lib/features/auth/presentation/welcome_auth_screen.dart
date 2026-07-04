import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/campus_tree_footer.dart';
import '../../../core/widgets/gradient_button.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

const _branches = ['ECS', 'CS', 'IT', 'AIML', 'MECH', 'EXTC'];
const _collegeCode = 'UNIPULSE';

class WelcomeAuthScreen extends ConsumerStatefulWidget {
  const WelcomeAuthScreen({super.key});

  @override
  ConsumerState<WelcomeAuthScreen> createState() => _WelcomeAuthScreenState();
}

class _WelcomeAuthScreenState extends ConsumerState<WelcomeAuthScreen> {
  var isLogin = true;

  final _loginPhoneController = TextEditingController();
  final _signupNameController = TextEditingController();
  final _signupRollController = TextEditingController();
  final _signupPhoneController = TextEditingController();
  String _signupBranch = _branches.first;
  int _signupYear = 1;

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _signupNameController.dispose();
    _signupRollController.dispose();
    _signupPhoneController.dispose();
    super.dispose();
  }

  String? _normalizedPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return null;
    return '+91$digits';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onContinue() async {
    final notifier = ref.read(authControllerProvider.notifier);

    if (isLogin) {
      final phone = _normalizedPhone(_loginPhoneController.text);
      if (phone == null) {
        _showError('Enter a valid 10-digit phone number');
        return;
      }
      await notifier.sendOtp(phoneNumber: phone, collegeCode: _collegeCode);
    } else {
      final phone = _normalizedPhone(_signupPhoneController.text);
      if (phone == null) {
        _showError('Enter a valid 10-digit phone number');
        return;
      }
      if (_signupNameController.text.trim().isEmpty ||
          _signupRollController.text.trim().isEmpty) {
        _showError('Please fill in your name and roll number');
        return;
      }
      await notifier.sendOtp(
        phoneNumber: phone,
        collegeCode: _collegeCode,
        pendingSignup: PendingSignupDetails(
          fullName: _signupNameController.text.trim(),
          rollNumber: _signupRollController.text.trim(),
          branch: _signupBranch,
          year: _signupYear,
        ),
      );
    }

    if (!mounted) return;
    final status = ref.read(authControllerProvider).status;
    if (status == AuthStatus.codeSent) {
      context.go('/otp');
    } else if (status == AuthStatus.error) {
      final message = ref.read(authControllerProvider).errorMessage;
      _showError(message ?? 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 160),
              children: [
                const _CampusHero(),
                const SizedBox(height: 28),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF101223),
                    ),
                    children: [
                      TextSpan(text: 'Welcome to '),
                      TextSpan(
                        text: 'UniPulse',
                        style: TextStyle(color: Color(0xFFFF5A1A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The Pulse of Your Campus',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B6D80)),
                ),
                const SizedBox(height: 28),
                _AuthToggle(
                  isLogin: isLogin,
                  onChanged: (value) => setState(() => isLogin = value),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: isLogin
                      ? _LoginForm(phoneController: _loginPhoneController)
                      : _SignupForm(
                          nameController: _signupNameController,
                          rollController: _signupRollController,
                          phoneController: _signupPhoneController,
                          selectedBranch: _signupBranch,
                          onBranchChanged: (b) => setState(() => _signupBranch = b),
                          selectedYear: _signupYear,
                          onYearChanged: (y) => setState(() => _signupYear = y),
                        ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: isLoading
                      ? 'Please wait…'
                      : (isLogin ? 'Continue' : 'Create Account'),
                  icon: Icons.arrow_forward,
                  onPressed: isLoading ? () {} : _onContinue,
                ),
              ],
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CampusTreeFooter(height: 120),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusHero extends StatelessWidget {
  const _CampusHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Center(
        child: Icon(Icons.school_rounded, size: 110, color: Color(0xFFFF7A1A)),
      ),
    );
  }
}

class _AuthToggle extends StatelessWidget {
  const _AuthToggle({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleItem(
              label: 'LOGIN',
              selected: isLogin,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _ToggleItem(
              label: 'SIGN UP',
              selected: !isLogin,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF7A1A), Color(0xFFEC1E6C)],
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF101223),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({required this.phoneController});

  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      children: [
        const Icon(Icons.phone_iphone_rounded, color: Color(0xFFFF5A1A), size: 34),
        const SizedBox(height: 24),
        const _Label('Phone Number'),
        _Input(prefix: '+91', hint: '98765 43210', controller: phoneController),
        const SizedBox(height: 18),
        const Text(
          'We will send you a secure OTP',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF9295A4)),
        ),
      ],
    );
  }
}

class _SignupForm extends StatelessWidget {
  const _SignupForm({
    required this.nameController,
    required this.rollController,
    required this.phoneController,
    required this.selectedBranch,
    required this.onBranchChanged,
    required this.selectedYear,
    required this.onYearChanged,
  });

  final TextEditingController nameController;
  final TextEditingController rollController;
  final TextEditingController phoneController;
  final String selectedBranch;
  final ValueChanged<String> onBranchChanged;
  final int selectedYear;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      children: [
        const _Label('Full Name'),
        _Input(hint: 'Enter your full name', controller: nameController),
        const SizedBox(height: 14),
        const _Label('Roll Number'),
        _Input(hint: 'e.g. VU3F2526129', controller: rollController),
        const SizedBox(height: 14),
        const _Label('Branch'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _branches
              .map((branch) => _Chip(
                    branch,
                    selected: branch == selectedBranch,
                    onTap: () => onBranchChanged(branch),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),
        const _Label('Year'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [1, 2, 3, 4]
              .map((year) => _Chip(
                    'Year $year',
                    selected: year == selectedYear,
                    onTap: () => onYearChanged(year),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),
        const _Label('Phone Number'),
        _Input(prefix: '+91', hint: '98765 43210', controller: phoneController),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 24),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w700));
}

class _Input extends StatelessWidget {
  const _Input({this.prefix, required this.hint, required this.controller});

  final String? prefix;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3E3EA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (prefix != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(prefix!),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType:
                  prefix != null ? TextInputType.phone : TextInputType.text,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFA0A2AD)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF6B1A) : Colors.transparent,
            border: Border.all(color: const Color(0xFFFF6B1A)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(color: selected ? Colors.white : const Color(0xFF101223)),
          ),
        ),
      );
}
