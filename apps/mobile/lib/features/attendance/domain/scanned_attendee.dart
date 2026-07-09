class ScannedAttendee {
  const ScannedAttendee({
    required this.registrationId,
    required this.eventTitle,
    required this.fullName,
    required this.rollNumber,
    required this.phone,
    required this.branch,
    required this.checkedIn,
    required this.checkedOut,
    required this.checkInTime,
    required this.checkOutTime,
  });

  factory ScannedAttendee.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>? ?? const {};
    final event = json['event'] as Map<String, dynamic>? ?? const {};
    final registration = json['registration'] as Map<String, dynamic>? ?? const {};
    final attendance = json['attendance'] as Map<String, dynamic>?;

    return ScannedAttendee(
      registrationId: registration['_id'] as String? ?? '',
      eventTitle: event['title'] as String? ?? '',
      fullName: student['fullName'] as String? ?? 'Unknown',
      rollNumber: student['rollNumber'] as String? ?? '',
      phone: student['phone'] as String? ?? '',
      branch: student['branch'] as String? ?? '',
      checkedIn: attendance?['checkedIn'] as bool? ?? false,
      checkedOut: attendance?['checkedOut'] as bool? ?? false,
      checkInTime: attendance?['checkInTime'] != null
          ? DateTime.tryParse(attendance!['checkInTime'] as String)
          : null,
      checkOutTime: attendance?['checkOutTime'] != null
          ? DateTime.tryParse(attendance!['checkOutTime'] as String)
          : null,
    );
  }

  final String registrationId;
  final String eventTitle;
  final String fullName;
  final String rollNumber;
  final String phone;
  final String branch;
  final bool checkedIn;
  final bool checkedOut;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
}
