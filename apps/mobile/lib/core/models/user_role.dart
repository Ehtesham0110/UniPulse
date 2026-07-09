enum UserRole {
  student,
  organizer,
  admin,
  superAdmin;

  bool get canSeeAdminPanel => this != UserRole.student;

  /// Mirrors the backend's MARK_ATTENDANCE permission, which — unlike
  /// most admin-ish permissions — is granted to Organizer and Super Admin
  /// but NOT to plain Admin (see shared/utils/roles.js on the backend).
  bool get canScanAttendance => this == UserRole.organizer || this == UserRole.superAdmin;
}
