class EarnedCertificate {
  const EarnedCertificate({
    required this.id,
    required this.certificateNumber,
    required this.issuedAt,
    required this.eventTitle,
    required this.eventVenue,
    required this.eventDate,
    required this.pdfPath,
  });

  factory EarnedCertificate.fromJson(Map<String, dynamic> json) {
    final event = json['eventId'];
    final eventMap = event is Map<String, dynamic> ? event : null;
    return EarnedCertificate(
      id: json['_id'] as String,
      certificateNumber: json['certificateNumber'] as String? ?? '',
      issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? '') ?? DateTime.now(),
      eventTitle: eventMap?['title'] as String? ?? 'Event',
      eventVenue: eventMap?['venue'] as String? ?? '',
      eventDate: eventMap?['eventDate'] != null
          ? DateTime.tryParse(eventMap!['eventDate'] as String)
          : null,
      // Relative API path, e.g. /api/certificates/<id>/download — combined
      // with the API origin + an access token at open/download time.
      pdfPath: json['pdfUrl'] as String? ?? '/api/certificates/${json['_id']}/download',
    );
  }

  final String id;
  final String certificateNumber;
  final DateTime issuedAt;
  final String eventTitle;
  final String eventVenue;
  final DateTime? eventDate;
  final String pdfPath;
}
