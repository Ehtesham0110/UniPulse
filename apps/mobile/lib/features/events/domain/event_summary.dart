class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.venue,
    required this.eventDate,
    required this.startTime,
    required this.eventType,
    required this.teamMin,
    required this.teamMax,
    required this.paid,
    required this.price,
    required this.lifecycle,
    required this.maximumParticipants,
    required this.currentParticipants,
  });

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    return EventSummary(
      id: json['_id'] as String,
      title: json['title'] as String? ?? 'Untitled Event',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Non Tech',
      venue: json['venue'] as String? ?? 'TBA',
      eventDate: json['eventDate'] != null
          ? DateTime.tryParse(json['eventDate'] as String)
          : null,
      startTime: json['startTime'] as String? ?? '',
      eventType: json['eventType'] as String? ?? 'Individual',
      teamMin: (json['teamMin'] as num?)?.toInt() ?? 1,
      teamMax: (json['teamMax'] as num?)?.toInt() ?? 1,
      paid: json['paid'] as bool? ?? false,
      price: (json['price'] as num?)?.toInt() ?? 0,
      lifecycle: json['lifecycle'] as String? ?? 'Draft',
      maximumParticipants: (json['maximumParticipants'] as num?)?.toInt(),
      currentParticipants: (json['currentParticipants'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String title;
  final String description;
  final String category;
  final String venue;
  final DateTime? eventDate;
  final String startTime;
  final String eventType; // 'Individual' | 'Team'
  final int teamMin;
  final int teamMax;
  final bool paid;
  final int price;
  final String lifecycle;
  final int? maximumParticipants;
  final int currentParticipants;

  bool get isTeamEvent => eventType == 'Team';
  bool get isRegistrationOpen => lifecycle == 'Registration Open';
  bool get isFull =>
      maximumParticipants != null && currentParticipants >= maximumParticipants!;
}
