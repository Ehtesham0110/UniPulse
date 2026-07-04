import '../../../core/models/user_role.dart';

UserRole roleFromBackend(String role) {
  switch (role) {
    case 'Organizer':
      return UserRole.organizer;
    case 'Admin':
      return UserRole.admin;
    case 'Super Admin':
      return UserRole.superAdmin;
    case 'Student':
    default:
      return UserRole.student;
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.collegeId,
    required this.fullName,
    required this.phone,
    required this.rollNumber,
    required this.branch,
    required this.year,
    required this.role,
    this.profilePictureUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['_id'] as String,
      collegeId: json['collegeId'] as String,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String,
      rollNumber: json['rollNumber'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      year: json['year'] as int? ?? 1,
      role: roleFromBackend(json['role'] as String? ?? 'Student'),
      profilePictureUrl: json['profilePictureUrl'] as String?,
    );
  }

  final String id;
  final String collegeId;
  final String fullName;
  final String phone;
  final String rollNumber;
  final String branch;
  final int year;
  final UserRole role;
  final String? profilePictureUrl;
}
