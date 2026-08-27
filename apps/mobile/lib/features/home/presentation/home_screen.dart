import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatting.dart';
// Removed: import '../../../core/widgets/campus_tree_footer.dart';
import '../../auth/application/auth_controller.dart';
import '../../events/application/event_providers.dart';
import '../../events/data/event_api.dart';
import '../../events/domain/event_summary.dart';
import '../../notifications/application/notification_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final highlightsAsync = ref.watch(eventListProvider(const EventListQuery()));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20), // reduced bottom padding
        children: [
          // ---------- App Bar (centered logo, right actions) ----------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Center(
                  child: Text.rich(
                    TextSpan(
                      text: 'Uni',
                      children: [
                        TextSpan(
                          text: 'Pulse',
                          style: TextStyle(color: Color(0xFFFF4F16)),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => context.push('/calendar'),
                        icon: const Icon(Icons.calendar_month_rounded),
                        tooltip: 'Event Calendar',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F5F5),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      if (user != null && user.role.canSeeAdminPanel)
                        IconButton(
                          onPressed: () => context.push('/admin'),
                          icon: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Color(0xFFFF5A1A),
                          ),
                          tooltip: 'Admin Panel',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F5F5),
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      const _NotificationBellButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ---------- Profile Header (card style) ----------
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFE7F6E6),
                  child: Icon(
                    Icons.person,
                    size: 42,
                    color: Color(0xFF24A546),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user != null ? 'Hey, ${user.fullName.split(' ').first}' : 'Hey there',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        children: [
                          Text(
                            user != null ? '${_yearLabel(user.year)}, ${user.branch}' : '',
                            style: const TextStyle(color: Color(0xFF65687A)),
                          ),
                          if (user != null && user.rollNumber.isNotEmpty)
                            _RollBadge(rollNumber: user.rollNumber),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // ---------- Explore Events ----------
          const Text(
            'Explore Events',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Discover exciting events happening across your campus.', // updated text
            style: TextStyle(color: Color(0xFF65687A)),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CategoryCard(
                  label: 'Non Tech Events',
                  subtitle: 'Fun. Creative.\nBeyond Tech.',
                  gradientColors: const [Color(0xFFFFE7A3), Color(0xFFFFF6E0)],
                  arrowColor: const Color(0xFFFF851A),
                  illustrationAsset: 'assets/illustrations/trophy.png',
                  illustrationBuilder: _TrophyIllustration.new,
                  onTap: () => context.push('/events/Non Tech'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CategoryCard(
                  label: 'Tech Events',
                  subtitle: 'Innovate. Build.\nCompete.',
                  gradientColors: const [Color(0xFFDCC5FF), Color(0xFFF1E8FF)],
                  arrowColor: const Color(0xFF8A42E8),
                  illustrationAsset: 'assets/illustrations/laptop_code.png',
                  illustrationBuilder: _LaptopCodeIllustration.new,
                  onTap: () => context.push('/events/Tech'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 42), // increased from 32

          // ---------- Upcoming Highlights ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Highlights',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              GestureDetector(
                onTap: () => context.push('/calendar'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Calendar',
                      style: TextStyle(
                        color: Color(0xFFFF4F16),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFFFF4F16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---------- Upcoming Events List ----------
          highlightsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Could not load upcoming events right now.',
                style: TextStyle(color: Color(0xFF696C7E)),
              ),
            ),
            data: (events) {
              final upcoming = events.take(3).toList();
              if (upcoming.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'No upcoming events yet — check back soon!',
                    style: TextStyle(color: Color(0xFF696C7E)),
                  ),
                );
              }
              return Column(
                children: [
                  for (final event in upcoming) ...[
                    _HighlightCard(event: event),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _yearLabel(int year) {
    switch (year) {
      case 1:
        return 'First Year';
      case 2:
        return 'Second Year';
      case 3:
        return 'Third Year';
      case 4:
        return 'Fourth Year';
      default:
        return 'Year $year';
    }
  }
}

// ---------------------------------------------------------------------
// Supporting widgets (only minimal changes)
// ---------------------------------------------------------------------

class _RollBadge extends StatelessWidget {
  const _RollBadge({required this.rollNumber});
  final String rollNumber;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD9F8D9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          rollNumber,
          style: const TextStyle(color: Color(0xFF22A33A), fontWeight: FontWeight.w700),
        ),
      );
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.arrowColor,
    required this.illustrationAsset,
    required this.illustrationBuilder,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final Color arrowColor;
  final String illustrationAsset;
  final Widget Function({Key? key}) illustrationBuilder;
  final VoidCallback onTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 216,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), // increased internal padding
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withValues(alpha: _pressed ? 0.28 : 0.5),
                blurRadius: _pressed ? 16 : 30,
                spreadRadius: _pressed ? -2 : 0,
                offset: Offset(0, _pressed ? 5 : 12),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ~45%: illustration
                  Expanded(
                    flex: 45,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _IllustrationWithSparkles(
                        assetPath: widget.illustrationAsset,
                        fallbackBuilder: widget.illustrationBuilder,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ~40%: title + subtitle
                  Expanded(
                    flex: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2130),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF44465A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ~15%: reserved blank space
                  const Expanded(flex: 15, child: SizedBox.shrink()),
                ],
              ),
              // Arrow button remains at bottom-right (unchanged)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: widget.arrowColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustrationWithSparkles extends StatelessWidget {
  const _IllustrationWithSparkles({
    required this.assetPath,
    required this.fallbackBuilder,
  });

  final String assetPath;
  final Widget Function({Key? key}) fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Positioned(top: 2, right: 4, child: _Sparkle(size: 9, opacity: 0.55)),
          const Positioned(bottom: 10, left: 0, child: _Sparkle(size: 6, opacity: 0.4)),
          const Positioned(top: 30, right: -6, child: _Dot(size: 5, opacity: 0.35)),
          Center(
            child: SizedBox(
              width: 86,
              height: 86,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => fallbackBuilder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.auto_awesome_rounded,
        size: size,
        color: Colors.white.withValues(alpha: opacity),
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

/// Vector fallback for Non-Tech card
class _TrophyIllustration extends StatelessWidget {
  const _TrophyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: 0,
          child: Container(
            width: 46,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFB8791E),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Positioned(
          bottom: 6,
          child: Container(
            width: 16,
            height: 16,
            color: const Color(0xFFE8A93A),
          ),
        ),
        Positioned(
          bottom: 18,
          child: Container(
            width: 40,
            height: 34,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFD766), Color(0xFFE8A93A)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
          ),
        ),
        Positioned(
          bottom: 34,
          left: 6,
          child: Container(
            width: 12,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8A93A), width: 2.5),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
            ),
          ),
        ),
        Positioned(
          bottom: 34,
          right: 6,
          child: Container(
            width: 12,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8A93A), width: 2.5),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
            ),
          ),
        ),
        const Positioned(
          top: 4,
          child: Icon(Icons.star_rounded, size: 26, color: Color(0xFFFFE9A8)),
        ),
      ],
    );
  }
}

/// Vector fallback for Tech card
class _LaptopCodeIllustration extends StatelessWidget {
  const _LaptopCodeIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: 0,
          child: Container(
            width: 62,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3D52),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Positioned(
          bottom: 6,
          child: Container(
            width: 62,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF23253A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF14162A),
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.center,
              child: const Text(
                '</>',
                style: TextStyle(
                  color: Color(0xFFFF851A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends ConsumerWidget {
  const _HighlightCard({required this.event});
  final EventSummary event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLabel = event.eventDate != null ? formatEventDate(event.eventDate!) : 'Date TBA';

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 18),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0CE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  event.isTech ? Icons.laptop_mac_rounded : Icons.emoji_events_rounded,
                  color: const Color(0xFFFF851A),
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('$dateLabel  |  ${event.startTime.isEmpty ? 'TBA' : event.startTime}'),
                  const SizedBox(height: 6),
                  Text(event.venue),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                event.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: event.isBookmarked ? const Color(0xFFFF6B1A) : null,
              ),
              onPressed: () => toggleEventBookmark(ref, event.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(myNotificationsProvider.select(
      (state) => state.maybeWhen(data: (page) => page.unreadCount, orElse: () => 0),
    ));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF5F5F5),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(8),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}