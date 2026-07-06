import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../certificates/presentation/certificates_screen.dart';
import '../../my_events/presentation/my_events_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../qr_scanner/presentation/qr_scanner_screen.dart';
import '../application/home_tab_provider.dart';
import 'home_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  var index = 0;

  final screens = const [
    HomeScreen(),
    MyEventsScreen(),
    QrScannerScreen(),
    CertificatesScreen(),
    ProfileScreen(),
  ];

  void _selectTab(int value) {
    setState(() => index = value);
    ref.read(homeTabIndexProvider.notifier).state = value;
  }

  @override
  Widget build(BuildContext context) {
    // Lets flows outside the shell (e.g. a successful payment) switch tabs
    // — e.g. jump to "My Events" — without a direct widget reference.
    ref.listen<int>(homeTabIndexProvider, (previous, next) {
      if (next != index) setState(() => index = next);
    });

    return Scaffold(
      body: screens[index],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12), blurRadius: 24),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: index == 0,
              onTap: () => _selectTab(0),
            ),
            _NavItem(
              icon: Icons.event_available_rounded,
              label: 'My Events',
              selected: index == 1,
              onTap: () => _selectTab(1),
            ),
            _QrButton(
              selected: index == 2,
              onTap: () => _selectTab(2),
            ),
            _NavItem(
              icon: Icons.workspace_premium_rounded,
              label: 'Certificates',
              selected: index == 3,
              onTap: () => _selectTab(3),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              selected: index == 4,
              onTap: () => _selectTab(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFF6B1A) : const Color(0xFF252733);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrButton extends StatelessWidget {
  const _QrButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFFA01B), Color(0xFFFF4B16)],
          ),
        ),
        child: const Icon(
          Icons.qr_code_scanner_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
