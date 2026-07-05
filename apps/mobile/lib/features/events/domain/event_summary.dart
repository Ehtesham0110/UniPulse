class EventScheduleItem {
  const EventScheduleItem({required this.time, required this.title, this.description});

  factory EventScheduleItem.fromJson(Map<String, dynamic> json) => EventScheduleItem(
        time: json['time'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
      );

  final String time;
  final String title;
  final String? description;
}

class EventOrganizer {
  const EventOrganizer({this.name, this.contactNumber, this.email});

  factory EventOrganizer.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EventOrganizer();
    return EventOrganizer(
      name: json['name'] as String?,
      contactNumber: json['contactNumber'] as String?,
      email: json['email'] as String?,
    );
  }

  final String? name;
  final String? contactNumber;
  final String? email;

  bool get hasInfo => name != null || contactNumber != null || email != null;
}

class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.venue,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.eventType,
    required this.teamMin,
    required this.teamMax,
    required this.paid,
    required this.price,
    required this.lifecycle,
    required this.maximumParticipants,
    required this.currentParticipants,
    required this.isBookmarked,
    required this.bannerUrl,
    required this.thumbnailUrl,
    required this.galleryUrls,
    required this.highlights,
    required this.rules,
    required this.schedule,
    required this.organizer,
  });

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    final media = json['media'] as Map<String, dynamic>?;
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
      endTime: json['endTime'] as String? ?? '',
      eventType: json['eventType'] as String? ?? 'Individual',
      teamMin: (json['teamMin'] as num?)?.toInt() ?? 1,
      teamMax: (json['teamMax'] as num?)?.toInt() ?? 1,
      paid: json['paid'] as bool? ?? false,
      price: (json['price'] as num?)?.toInt() ?? 0,
      lifecycle: json['lifecycle'] as String? ?? 'Draft',
      maximumParticipants: (json['maximumParticipants'] as num?)?.toInt(),
      currentParticipants: (json['currentParticipants'] as num?)?.toInt() ?? 0,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      bannerUrl: media?['bannerUrl'] as String?,
      thumbnailUrl: media?['thumbnailUrl'] as String?,
      galleryUrls: (media?['galleryUrls'] as List<dynamic>?)?.cast<String>() ?? const [],
      highlights: (json['highlights'] as List<dynamic>?)?.cast<String>() ?? const [],
      rules: (json['rules'] as List<dynamic>?)?.cast<String>() ?? const [],
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((e) => EventScheduleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      organizer: EventOrganizer.fromJson(json['organizer'] as Map<String, dynamic>?),
    );
  }

  final String id;
  final String title;
  final String description;
  final String category;
  final String venue;
  final DateTime? eventDate;
  final String startTime;
  final String endTime;
  final String eventType; // 'Individual' | 'Team'
  final int teamMin;
  final int teamMax;
  final bool paid;
  final int price;
  final String lifecycle;
  final int? maximumParticipants;
  final int currentParticipants;
  final bool isBookmarked;
  final String? bannerUrl;
  final String? thumbnailUrl;
  final List<String> galleryUrls;
  final List<String> highlights;
  final List<String> rules;
  final List<EventScheduleItem> schedule;
  final EventOrganizer organizer;

  bool get isTeamEvent => eventType == 'Team';
  bool get isRegistrationOpen => lifecycle == 'Registration Open';
  bool get isFull =>
      maximumParticipants != null && currentParticipants >= maximumParticipants!;
  bool get isTech => category == 'Tech';
}
