import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_certificates_screen.dart';
import '../../features/admin/presentation/admin_notifications_screen.dart';
import '../../features/admin/presentation/admin_panel_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/complete_profile_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/welcome_auth_screen.dart';
import '../../features/events/presentation/event_detail_screen.dart';
import '../../features/events/presentation/event_list_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

const _authScreenPaths = {'/welcome', '/otp', '/complete-profile'};

/// Notifies GoRouter to re-evaluate `redirect` whenever auth status changes,
/// e.g. after OTP verification completes or the user logs out.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.status != next.status) {
        notifyListeners();
      }
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authStatus = ref.read(authControllerProvider).status;
      final location = state.matchedLocation;

      // Splash screen owns the auto-login check; let it run before we
      // make any redirect decisions.
      if (location == '/') return null;

      final isOnAuthScreen = _authScreenPaths.contains(location);

      if (authStatus == AuthStatus.authenticated && isOnAuthScreen) {
        return '/home';
      }

      final loggedOutStatuses = {AuthStatus.unauthenticated, AuthStatus.error};
      final protectedPrefixes = ['/home', '/events', '/event', '/admin', '/notifications'];
      final isOnProtectedRoute =
          protectedPrefixes.any((prefix) => location.startsWith(prefix));

      if (loggedOutStatuses.contains(authStatus) && isOnProtectedRoute) {
        return '/welcome';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeAuthScreen(),
      ),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      GoRoute(
        path: '/events/:category',
        builder: (context, state) => EventListScreen(
          category: state.pathParameters['category'] ?? 'Non Tech',
        ),
      ),
      GoRoute(
        path: '/event/:id',
        builder: (context, state) => EventDetailScreen(
          eventId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminPanelScreen(),
      ),
      GoRoute(
        path: '/admin/certificates',
        builder: (context, state) => const AdminCertificatesScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/admin/notifications',
        builder: (context, state) => const AdminNotificationsScreen(),
      ),
    ],
  );
});
