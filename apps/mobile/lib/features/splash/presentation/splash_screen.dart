import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/campus_tree_footer.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..forward();

    // Kick off the auto-login check (reads secure storage, validates the
    // session with the backend) in parallel with the splash animation.
    Future.microtask(() => ref.read(authControllerProvider.notifier).tryAutoLogin());

    Future<void>.delayed(const Duration(milliseconds: 1150), _navigateOnceReady);
  }

  Future<void> _navigateOnceReady() async {
    if (!mounted) return;

    var status = ref.read(authControllerProvider).status;
    // The animation delay is usually enough, but if the network call is
    // still in flight, wait briefly for it rather than guessing.
    var attempts = 0;
    while (status == AuthStatus.unknown || status == AuthStatus.loading) {
      if (attempts >= 20 || !mounted) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      status = ref.read(authControllerProvider).status;
      attempts++;
    }

    if (!mounted) return;
    context.go(status == AuthStatus.authenticated ? '/home' : '/welcome');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.12).animate(
          CurvedAnimation(parent: _controller, curve: const Interval(0.86, 1)),
        ),
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  final morph =
                      t < 0.25 ? 0.0 : ((t - 0.25) / 0.45).clamp(0.0, 1.0);
                  final bounce = t > 0.65
                      ? 1 + (0.06 * (1 - ((t - 0.65) / 0.2).clamp(0, 1)))
                      : 1.0;
                  return Transform.scale(
                    scale: bounce,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          morph > 0.5 ? '6' : 'U',
                          style: const TextStyle(
                            fontSize: 78,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF32CE29),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Text(
                          morph > 0.5 ? '7' : 'P',
                          style: const TextStyle(
                            fontSize: 78,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEF2A25),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CampusTreeFooter(),
            ),
          ],
        ),
      ),
    );
  }
}
