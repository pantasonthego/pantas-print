class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String department;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.department,
    required this.createdAt,
  });

  // Getters for backward compatibility with existing code
  String get name => fullName;
  String get userId => id;
  String get departmentOrCompany => department;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? json['user_id'] ?? 'PANTAS_${DateTime.now().millisecondsSinceEpoch}',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      department: json['department'] ?? json['department_or_company'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'department': department,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String toVCard() {
    return 'BEGIN:VCARD\n'
        'VERSION:3.0\n'
        'FN:$fullName\n'
        'TEL;TYPE=CELL:$phone\n'
        'EMAIL:$email\n'
        'ORG:$department\n'
        'NOTE:PANTAS PRINT User ID: $id\n'
        'END:VCARD';
  }
}
