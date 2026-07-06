import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the currently selected tab in [HomeShell]. Exists so flows
/// outside the shell (e.g. returning to "My Events" after a successful
/// payment) can switch tabs without needing a direct widget reference.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);
