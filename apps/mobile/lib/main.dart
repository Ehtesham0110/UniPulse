import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/dev_mode.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isFirebaseConfigured) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } else {
    // Development Mode: firebase_options.dart still has REPLACE_ME
    // placeholders (flutterfire configure hasn't been run yet). Skip
    // Firebase entirely so the app can still launch and every screen can
    // be manually tested — see AI_HANDOVER.md → "Development Mode".
    // Authentication automatically falls back to a local mock session
    // (see features/auth/application/auth_controller.dart). This check
    // reverses itself automatically the moment real Firebase credentials
    // are installed — nothing else needs to change.
    debugPrint(
      '⚠️  UniPulse Development Mode: Firebase is not configured yet '
      '(firebase_options.dart has placeholder values). Skipping Firebase '
      'initialization and using a mock login instead. Run '
      '`flutterfire configure` from apps/mobile/ to enable real Firebase '
      'Authentication.',
    );
  }

  runApp(const ProviderScope(child: UniPulseApp()));
}
