class TeamMemberInput {
  const TeamMemberInput({required this.fullName, required this.phone, this.rollNumber});

  final String fullName;
  final String phone;
  final String? rollNumber;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'phone': phone,
        if (rollNumber != null && rollNumber!.isNotEmpty) 'rollNumber': rollNumber,
      };
}

/// A registration as returned by GET /registrations/me, with the parent
/// event populated so the UI can render a card without a second request.
class MyRegistration {
  const MyRegistration({
    required this.id,
    required this.status,
    required this.eventId,
    required this.eventTitle,
    required this.eventCategory,
    required this.eventVenue,
    required this.eventDate,
    required this.eventLifecycle,
  });

  factory MyRegistration.fromJson(Map<String, dynamic> json) {
    final event = json['eventId'];
    final eventMap = event is Map<String, dynamic> ? event : null;
    return MyRegistration(
      id: json['_id'] as String,
      status: json['status'] as String? ?? 'Confirmed',
      eventId: eventMap != null ? eventMap['_id'] as String? ?? '' : event as String? ?? '',
      eventTitle: eventMap?['title'] as String? ?? 'Event',
      eventCategory: eventMap?['category'] as String? ?? 'Non Tech',
      eventVenue: eventMap?['venue'] as String? ?? 'TBA',
      eventDate: eventMap?['eventDate'] != null
          ? DateTime.tryParse(eventMap!['eventDate'] as String)
          : null,
      eventLifecycle: eventMap?['lifecycle'] as String? ?? 'Draft',
    );
  }

  final String id;
  final String status;
  final String eventId;
  final String eventTitle;
  final String eventCategory;
  final String eventVenue;
  final DateTime? eventDate;
  final String eventLifecycle;

  bool get isPast => eventLifecycle == 'Completed' || eventLifecycle == 'Archived';
  bool get isCancelled => status == 'Cancelled';

  /// Mirrors the backend's GET /registrations/:id/qr eligibility rule —
  /// only Confirmed/Attended/Completed registrations have a QR to show.
  bool get hasQrCode => status == 'Confirmed' || status == 'Attended' || status == 'Completed';
}
