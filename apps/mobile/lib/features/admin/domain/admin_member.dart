class AdminMember {
  const AdminMember({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.email,
    this.rollNumber,
    this.branch,
    this.status,
  });

  factory AdminMember.fromJson(Map<String, dynamic> json) {
    return AdminMember(
      id: json['_id'] as String,
      fullName: json['fullName'] as String? ?? 'Admin',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'Admin',
      email: json['email'] as String?,
      rollNumber: json['rollNumber'] as String?,
      branch: json['branch'] as String?,
      status: json['status'] as String? ?? 'Active',
    );
  }

  final String id;
  final String fullName;
  final String phone;
  final String role;
  final String? email;
  final String? rollNumber;
  final String? branch;
  final String? status;

  bool get isSuperAdmin => role == 'Super Admin';
  bool get isAdmin => role == 'Admin' || isSuperAdmin;
}
