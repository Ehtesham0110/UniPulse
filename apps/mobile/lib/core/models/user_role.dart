enum UserRole {
  student,
  organizer,
  admin,
  superAdmin;

  bool get canSeeAdminPanel => this != UserRole.student;
}
