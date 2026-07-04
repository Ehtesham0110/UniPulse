import 'package:flutter/material.dart';

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Container(color: Colors.black87),
          Positioned(
            left: 24,
            right: 24,
            top: 36,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFFFF8A1A),
                    child: Icon(Icons.qr_code_scanner, color: Colors.white),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Scan the QR code at the event\nPosition the QR code within the frame to scan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white70,
                  size: 160,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 150,
            child: Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFF171717),
                child: Icon(Icons.flashlight_on_rounded, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 132,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFFFE8DF),
                    child: Icon(Icons.qr_code, color: Color(0xFFFF5A1A)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Can’t scan?\nMake sure the QR code is clear and there is enough light.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Enter Code'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
