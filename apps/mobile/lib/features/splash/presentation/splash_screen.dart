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
    with TickerProviderStateMixin {
  // Drives the one-shot "UP -> UniPulse" assembly. Duration sits in the
  // requested 1.3-1.5s band.
  late final AnimationController _logoController;

  // Starts once _logoController completes: a slow, subtle scale pulse so
  // the finished wordmark doesn't sit dead-still while auto-login runs.
  late final AnimationController _breatheController;
  late final Animation<double> _breathe;

  static const _greenU = Color(0xFF32CE29);
  static const _orangeP = Color(0xFFFF6B1A);
  static const _neutral = Color(0xFF101223);

  static const _bigFontSize = 74.0;
  static const _finalFontSize = 40.0;
  // How many multiples of the hidden letters' own width to reserve as the
  // initial "big UP" gap — this is what makes U/P start far apart, then
  // draw together as it eases down to 1.0 (natural width).
  static const _bigGapFactor = 3.6;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _breathe = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _logoController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _breatheController.repeat(reverse: true);
      }
    });

    // --- Untouched: auto-login + navigation timing flow ---
    // Kick off the auto-login check (reads secure storage, validates the
    // session with the backend) in parallel with the splash animation.
    Future.microtask(() => ref.read(authControllerProvider.notifier).tryAutoLogin());

    Future<void>.delayed(const Duration(milliseconds: 2400), _navigateOnceReady);
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
  // --- End untouched section ---

  @override
  void dispose() {
    _logoController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Clean white base with a barely-there warm radial gradient —
          // adds depth without reading as "colored background".
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [Colors.white, Color(0xFFFFF8F2)],
          ),
        ),
        child: Stack(
          children: [
            Center(child: _AnimatedWordmark(
              controller: _logoController,
              breathe: _breathe,
              greenU: _greenU,
              orangeP: _orangeP,
              neutral: _neutral,
              bigFontSize: _bigFontSize,
              finalFontSize: _finalFontSize,
              bigGapFactor: _bigGapFactor,
            )),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // ~70% shorter than the previous default (130 -> 38), used
              // purely as a decorative footer, never competing with the
              // centered logo above it.
              child: CampusTreeFooter(height: 38, fadeTop: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "UP -> UniPulse" assembly + breathing wordmark. Pure presentation —
/// no navigation or auth logic lives here.
class _AnimatedWordmark extends StatelessWidget {
  const _AnimatedWordmark({
    required this.controller,
    required this.breathe,
    required this.greenU,
    required this.orangeP,
    required this.neutral,
    required this.bigFontSize,
    required this.finalFontSize,
    required this.bigGapFactor,
  });

  final AnimationController controller;
  final Animation<double> breathe;
  final Color greenU;
  final Color orangeP;
  final Color neutral;
  final double bigFontSize;
  final double finalFontSize;
  final double bigGapFactor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, breathe]),
      builder: (context, child) {
        final t = controller.value;

        // Phase 1 (0 -> 0.30): U and P fade + scale in together, large,
        // far apart.
        final popT = const Interval(0.0, 0.30, curve: Curves.easeOutBack)
            .transform(t);
        final popOpacity = popT.clamp(0.0, 1.0);
        final popScale = 0.65 + (0.35 * popT);

        // Phase 2 (0.30 -> 0.65): font size eases from big to final —
        // this is the "letters move closer together" motion, since the
        // whole row shrinks and re-centers as it happens.
        final sizeT = const Interval(0.30, 0.65, curve: Curves.easeInOutCubic)
            .transform(t);
        final fontSize = lerpDouble(bigFontSize, finalFontSize, sizeT);

        // The "ni" slot: starts reserved at `bigGapFactor` * its own
        // width (the big visual gap between U and P), eases down to
        // exactly 1x its natural width by t=1.0. U/P are effectively
        // "fixed" once this (and the trailing slot below) finish — they
        // don't move again after t=1.0, only the reveal completes.
        final midFactorT = const Interval(0.30, 1.0, curve: Curves.easeInOutCubic)
            .transform(t);
        final midWidthFactor = lerpDouble(bigGapFactor, 1.0, midFactorT);
        final midOpacity = const Interval(0.65, 1.0, curve: Curves.easeOut)
            .transform(t);

        // The "ulse" slot: doesn't exist until P has essentially arrived,
        // then grows in from zero width while fading in — completing the
        // word with no hard cut.
        final trailingFactorT = const Interval(0.55, 1.0, curve: Curves.easeOutCubic)
            .transform(t);
        final trailingOpacity = const Interval(0.65, 1.0, curve: Curves.easeOut)
            .transform(t);

        final letterStyle = TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.0,
        );

        return Transform.scale(
          scale: breathe.value,
          child: Opacity(
            opacity: popOpacity,
            child: Transform.scale(
              scale: popScale,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('U', style: letterStyle.copyWith(color: greenU)),
                  Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: midWidthFactor,
                    child: Opacity(
                      opacity: midOpacity,
                      child: Text('ni', style: letterStyle.copyWith(color: neutral)),
                    ),
                  ),
                  Text('P', style: letterStyle.copyWith(color: orangeP)),
                  Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: trailingFactorT,
                    child: Opacity(
                      opacity: trailingOpacity,
                      child: Text('ulse', style: letterStyle.copyWith(color: neutral)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;