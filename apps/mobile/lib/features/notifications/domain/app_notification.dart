class NotificationAudience {
  const NotificationAudience({required this.type, this.branch, this.year, this.clubId, this.eventId, this.userId});

  factory NotificationAudience.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NotificationAudience(type: 'College');
    return NotificationAudience(
      type: json['type'] as String? ?? 'College',
      branch: json['branch'] as String?,
      year: (json['year'] as num?)?.toInt(),
      clubId: json['clubId'] as String?,
      eventId: json['eventId'] as String?,
      userId: json['userId'] as String?,
    );
  }

  final String type;
  final String? branch;
  final int? year;
  final String? clubId;
  final String? eventId;
  final String? userId;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (branch != null) 'branch': branch,
        if (year != null) 'year': year,
        if (clubId != null) 'clubId': clubId,
        if (eventId != null) 'eventId': eventId,
        if (userId != null) 'userId': userId,
      };
}

/// A single item in a student's notification inbox — one per
/// (notification, student) delivery record.
class AppNotification {
  const AppNotification({
    required this.recipientId,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.audience,
    required this.sentAt,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final notification = json['notificationId'];
    final notificationMap = notification is Map<String, dynamic> ? notification : const {};
    return AppNotification(
      recipientId: json['_id'] as String,
      title: notificationMap['title'] as String? ?? 'Notification',
      body: notificationMap['body'] as String? ?? '',
      imageUrl: notificationMap['imageUrl'] as String?,
      audience: NotificationAudience.fromJson(notificationMap['audience'] as Map<String, dynamic>?),
      sentAt: DateTime.tryParse(notificationMap['sentAt'] as String? ?? '') ??
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  final String recipientId;
  final String title;
  final String body;
  final String? imageUrl;
  final NotificationAudience audience;
  final DateTime sentAt;
  final bool isRead;

  /// If this notification relates to a specific event (either it targeted
  /// that event's participants, or it's a club/individual send that still
  /// happens to carry an eventId), the notifications screen can deep-link
  /// straight to it.
  String? get relatedEventId => audience.eventId;
}

/// One row of the admin-facing "sent notifications" history.
class SentNotification {
  const SentNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.status,
    required this.recipientCount,
    required this.sentAt,
  });

  factory SentNotification.fromJson(Map<String, dynamic> json) => SentNotification(
        id: json['_id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        audience: NotificationAudience.fromJson(json['audience'] as Map<String, dynamic>?),
        status: json['status'] as String? ?? 'Sent',
        recipientCount: (json['recipientCount'] as num?)?.toInt() ?? 0,
        sentAt: DateTime.tryParse(json['sentAt'] as String? ?? json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String title;
  final String body;
  final NotificationAudience audience;
  final String status;
  final int recipientCount;
  final DateTime sentAt;
}
