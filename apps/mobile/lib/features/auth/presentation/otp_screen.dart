import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/campus_tree_footer.dart';
import '../../../core/widgets/gradient_button.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_code.length == 6) {
      FocusScope.of(context).unfocus();
      ref.read(authControllerProvider.notifier).verifyOtp(_code);
    }
  }

  void _resend() {
    final authState = ref.read(authControllerProvider);
    final phone = authState.phoneNumber;
    if (phone == null) return;
    for (final c in _controllers) {
      c.clear();
    }
    ref.read(authControllerProvider.notifier).sendOtp(
          phoneNumber: phone,
          collegeCode: authState.collegeCode,
          pendingSignup: authState.pendingSignup,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      } else if (next.status == AuthStatus.signupRequired) {
        context.go('/complete-profile');
      } else if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final phoneDisplay = authState.phoneNumber ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(
            text: 'Verify ',
            children: [
              TextSpan(
                text: 'OTP',
                style: TextStyle(color: Color(0xFFFF5A1A)),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 90),
            children: [
              _OtpHero(),
              const SizedBox(height: 18),
              const Text(
                'Enter the OTP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'We have sent a 6-digit OTP to your mobile number',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF696C7E)),
              ),
              const SizedBox(height: 8),
              Text(
                phoneDisplay,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter 6-digit OTP',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (index) => SizedBox(
                          width: 48,
                          height: 54,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            enabled: !isLoading,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE4E4EB)),
                              ),
                            ),
                            onChanged: (value) => _onDigitChanged(index, value),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: isLoading ? null : _resend,
                      child: const Text('Didn\'t get the code? Resend OTP'),
                    ),
                    const SizedBox(height: 6),
                    GradientButton(
                      label: isLoading ? 'Verifying…' : 'Verify & Continue',
                      icon: Icons.arrow_forward,
                      onPressed: isLoading
                          ? () {}
                          : () => ref
                              .read(authControllerProvider.notifier)
                              .verifyOtp(_code),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: CampusTreeFooter(height: 40, fadeTop: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same crop/cover treatment as the Welcome screen's hero, sized ~25%
/// larger than the old inline `ClipRRect` version and wrapped so it can
/// carry a subtle shadow (a bare `ClipRRect` can't paint one).
class _OtpHero extends StatelessWidget {
  const _OtpHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 225,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/illustrations/campus_students.png',
        fit: BoxFit.cover,
        alignment: const Alignment(0, 0.35),
      ),
    );
  }
}