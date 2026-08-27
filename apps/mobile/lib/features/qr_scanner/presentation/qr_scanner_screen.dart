import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../attendance/application/attendance_providers.dart';
import '../../attendance/data/attendance_api.dart';
import '../../attendance/domain/scanned_attendee.dart';
import '../../auth/application/auth_controller.dart';
import '../../events/application/event_providers.dart';
import '../../events/data/event_api.dart';

enum _ScanState { scanning, validating, attendeeInfo, actionLoading, success, failure }

enum QrPayloadType { poster, attendance, unknown }

class QrPayload {
  const QrPayload._({required this.type, this.eventId, this.attendanceToken});

  final QrPayloadType type;
  final String? eventId;
  final String? attendanceToken;

  factory QrPayload.parse(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return const QrPayload._(type: QrPayloadType.unknown);

    // 1. JSON Payload (e.g. {"eventId": "..."}, {"id": "...", "type": "poster"}, {"qrToken": "..."})
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final Map<String, dynamic> data = jsonDecode(trimmed) as Map<String, dynamic>;
        if (data['eventId'] is String && (data['eventId'] as String).trim().isNotEmpty) {
          return QrPayload._(type: QrPayloadType.poster, eventId: (data['eventId'] as String).trim());
        }
        if (data['id'] is String && (data['id'] as String).trim().isNotEmpty) {
          return QrPayload._(type: QrPayloadType.poster, eventId: (data['id'] as String).trim());
        }
        if (data['qrToken'] is String && (data['qrToken'] as String).trim().isNotEmpty) {
          return QrPayload._(
            type: QrPayloadType.attendance,
            attendanceToken: (data['qrToken'] as String).trim(),
          );
        }
      } catch (_) {}
    }

    // 2. Deep-link or Web URL Payload (e.g. https://unipulse.app/event/<id> or unipulse://event/<id>)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('unipulse://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final eventIdx = uri.pathSegments.indexOf('event');
        final eventsIdx = uri.pathSegments.indexOf('events');
        if (eventIdx != -1 && eventIdx + 1 < uri.pathSegments.length) {
          return QrPayload._(type: QrPayloadType.poster, eventId: uri.pathSegments[eventIdx + 1]);
        }
        if (eventsIdx != -1 && eventsIdx + 1 < uri.pathSegments.length) {
          return QrPayload._(type: QrPayloadType.poster, eventId: uri.pathSegments[eventsIdx + 1]);
        }
      }
    }

    // 3. Attendance Token (<registrationId>.<hmacSignature>)
    if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      if (parts.length == 2 && parts[0].trim().isNotEmpty && parts[1].trim().isNotEmpty) {
        return QrPayload._(type: QrPayloadType.attendance, attendanceToken: trimmed);
      }
    }

    // 4. Plain Mongo ObjectId / Event ID (24 hex characters)
    final objectIdRegex = RegExp(r'^[a-fA-F0-9]{24}$');
    if (objectIdRegex.hasMatch(trimmed)) {
      return QrPayload._(type: QrPayloadType.poster, eventId: trimmed);
    }

    // 5. General Alphanumeric Event Identifier Fallback
    if (!trimmed.contains(' ') && !trimmed.contains('/') && !trimmed.contains('.')) {
      return QrPayload._(type: QrPayloadType.poster, eventId: trimmed);
    }

    return const QrPayload._(type: QrPayloadType.unknown);
  }
}

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final _controller = MobileScannerController();

  _ScanState _state = _ScanState.scanning;
  ScannedAttendee? _attendee;
  String? _currentQrToken;
  String? _resultMessage;
  String? _resultReason;
  bool _wasCheckIn = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canScanAttendance => ref.read(authControllerProvider).user?.role.canScanAttendance ?? false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _state != _ScanState.scanning) return;
    final rawValue = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (rawValue == null || rawValue.isEmpty) return;

    _isProcessing = true;
    _processQr(rawValue);
  }

  Future<void> _processQr(String rawValue) async {
    final payload = QrPayload.parse(rawValue);

    switch (payload.type) {
      case QrPayloadType.poster:
        await _handlePosterQr(payload.eventId!);
        break;

      case QrPayloadType.attendance:
        await _validate(payload.attendanceToken!);
        break;

      case QrPayloadType.unknown:
        setState(() {
          _resultMessage = 'This QR code is not recognized by UniPulse.';
          _resultReason = 'INVALID_QR';
          _state = _ScanState.failure;
        });
        break;
    }
  }

  Future<void> _handlePosterQr(String eventId) async {
    setState(() => _state = _ScanState.validating);
    unawaited(_controller.stop());

    try {
      final event = await ref.read(eventApiProvider).getEvent(eventId);
      if (!mounted) return;

      _scanNext();
      await context.push('/event/${event.id}');
    } on EventApiException catch (error) {
      setState(() {
        _resultMessage = error.message;
        _resultReason = error.statusCode == 404 ? 'EVENT_NOT_FOUND' : 'INVALID_QR';
        _state = _ScanState.failure;
      });
    } catch (_) {
      setState(() {
        _resultMessage = 'Could not fetch event details. Check your connection.';
        _resultReason = null;
        _state = _ScanState.failure;
      });
    }
  }

  Future<void> _validate(String qrToken) async {
    setState(() => _state = _ScanState.validating);
    unawaited(_controller.stop());

    try {
      final attendee = await ref.read(attendanceApiProvider).validate(qrToken: qrToken);
      setState(() {
        _attendee = attendee;
        _currentQrToken = qrToken;
        _state = _ScanState.attendeeInfo;
      });
    } on AttendanceApiException catch (error) {
      setState(() {
        _resultMessage = error.message;
        _resultReason = error.reason;
        _state = _ScanState.failure;
      });
    } catch (_) {
      setState(() {
        _resultMessage = 'Could not reach the server. Please try again.';
        _resultReason = null;
        _state = _ScanState.failure;
      });
    }
  }

  Future<void> _checkIn() async {
    final qrToken = _currentQrToken;
    if (qrToken == null) return;
    setState(() => _state = _ScanState.actionLoading);

    try {
      final attendee = await ref.read(attendanceApiProvider).checkIn(
            qrToken: qrToken,
            scannerDevice: 'UniPulse App',
          );
      setState(() {
        _attendee = attendee;
        _wasCheckIn = true;
        _resultMessage = '${attendee.fullName} checked in successfully!';
        _resultReason = null;
        _state = _ScanState.success;
      });
    } on AttendanceApiException catch (error) {
      setState(() {
        _resultMessage = error.message;
        _resultReason = error.reason;
        _wasCheckIn = true;
        _state = _ScanState.failure;
      });
    } catch (_) {
      setState(() {
        _resultMessage = 'Could not reach the server. Please try again.';
        _resultReason = null;
        _state = _ScanState.failure;
      });
    }
  }

  Future<void> _checkOut() async {
    final qrToken = _currentQrToken;
    if (qrToken == null) return;
    setState(() => _state = _ScanState.actionLoading);

    try {
      final attendee = await ref.read(attendanceApiProvider).checkOut(
            qrToken: qrToken,
            scannerDevice: 'UniPulse App',
          );
      setState(() {
        _attendee = attendee;
        _wasCheckIn = false;
        _resultMessage = '${attendee.fullName} checked out successfully!';
        _resultReason = null;
        _state = _ScanState.success;
      });
    } on AttendanceApiException catch (error) {
      setState(() {
        _resultMessage = error.message;
        _resultReason = error.reason;
        _wasCheckIn = false;
        _state = _ScanState.failure;
      });
    } catch (_) {
      setState(() {
        _resultMessage = 'Could not reach the server. Please try again.';
        _resultReason = null;
        _state = _ScanState.failure;
      });
    }
  }

  void _scanNext() {
    setState(() {
      _state = _ScanState.scanning;
      _attendee = null;
      _currentQrToken = null;
      _resultMessage = null;
      _resultReason = null;
      _isProcessing = false;
    });
    unawaited(_controller.start());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_rounded),
          ),
          IconButton(
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Container(
                color: Colors.black,
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_rounded, size: 64, color: Color(0xFF9295A4)),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Access Required',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Please enable camera permissions in your device settings to scan event posters or attendance QR codes.'
                            : 'Could not initialize camera: ${error.errorDetails?.message ?? error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF9295A4)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          _ScannerFrameOverlay(active: _state == _ScanState.scanning),
          if (_state == _ScanState.validating)
            const _LoadingOverlay(label: 'Processing QR code…'),
          if (_state == _ScanState.actionLoading)
            const _LoadingOverlay(label: 'Updating attendance…'),
          if (_state == _ScanState.attendeeInfo && _attendee != null)
            _AttendeeInfoPanel(
              attendee: _attendee!,
              canScanAttendance: _canScanAttendance,
              onCheckIn: _checkIn,
              onCheckOut: _checkOut,
              onDismiss: _scanNext,
            ),
          if (_state == _ScanState.success)
            _ResultOverlay(
              success: true,
              title: _wasCheckIn ? 'Checked In!' : 'Checked Out!',
              message: _resultMessage ?? '',
              onScanNext: _scanNext,
            ),
          if (_state == _ScanState.failure)
            _ResultOverlay(
              success: false,
              title: _titleForReason(_resultReason),
              message: _resultMessage ?? 'Something went wrong.',
              isDuplicate: _resultReason == 'ALREADY_CHECKED_IN' ||
                  _resultReason == 'ALREADY_CHECKED_OUT',
              onScanNext: _scanNext,
            ),
        ],
      ),
    );
  }

  String _titleForReason(String? reason) {
    switch (reason) {
      case 'INVALID_QR':
        return 'Invalid QR Code';
      case 'EVENT_NOT_FOUND':
        return 'Event Not Found';
      case 'ALREADY_CHECKED_IN':
      case 'ALREADY_CHECKED_OUT':
        return 'Duplicate Scan';
      case 'CANCELLED':
        return 'Registration Cancelled';
      case 'PAYMENT_PENDING':
        return 'Payment Pending';
      case 'WRONG_EVENT':
        return 'Wrong Event';
      case 'EVENT_ENDED':
        return 'Event Ended';
      case 'NOT_CHECKED_IN':
        return 'Not Checked In';
      default:
        return 'Scan Failed';
    }
  }
}



class _ScannerFrameOverlay extends StatelessWidget {
  const _ScannerFrameOverlay({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Align the QR code within the frame',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _AttendeeInfoPanel extends StatelessWidget {
  const _AttendeeInfoPanel({
    required this.attendee,
    required this.canScanAttendance,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onDismiss,
  });

  final ScannedAttendee attendee;
  final bool canScanAttendance;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: Colors.black54),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFE7F6E6),
                      child: Icon(Icons.person, size: 32, color: Color(0xFF24A546)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attendee.fullName,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                          if (attendee.rollNumber.isNotEmpty || attendee.branch.isNotEmpty)
                            Text(
                              [attendee.rollNumber, attendee.branch]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style: const TextStyle(color: Color(0xFF696C7E)),
                            ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: onDismiss, icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(attendee.eventTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: attendee.checkedOut
                        ? const Color(0xFFE7F0FF)
                        : attendee.checkedIn
                            ? const Color(0xFFE7F6E6)
                            : const Color(0xFFF3F3F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    attendee.checkedOut
                        ? 'Already checked out'
                        : attendee.checkedIn
                            ? 'Checked in — not yet checked out'
                            : 'Not checked in yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: attendee.checkedOut
                          ? const Color(0xFF3A7BFF)
                          : attendee.checkedIn
                              ? const Color(0xFF22A33A)
                              : const Color(0xFF696C7E),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (canScanAttendance)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: attendee.checkedIn ? null : onCheckIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22A33A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Check In'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (attendee.checkedIn && !attendee.checkedOut) ? onCheckOut : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A7BFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Check Out'),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Scan Next', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.success,
    required this.title,
    required this.message,
    required this.onScanNext,
    this.isDuplicate = false,
  });

  final bool success;
  final String title;
  final String message;
  final bool isDuplicate;
  final VoidCallback onScanNext;

  @override
  Widget build(BuildContext context) {
    final color = success
        ? const Color(0xFF22A33A)
        : isDuplicate
            ? const Color(0xFFFFAA00)
            : const Color(0xFFD32F2F);
    final icon = success
        ? Icons.check_circle_rounded
        : isDuplicate
            ? Icons.warning_rounded
            : Icons.cancel_rounded;

    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.scale(scale: value, child: child),
                child: Icon(icon, size: 96, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onScanNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Scan Next', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
