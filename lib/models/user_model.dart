enum UserRole {
  parent,
  driver,
  assistant,
}

class UserModel {
  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  // Convert Firestore DocumentSnapshot / JSON Map to UserModel
  factory UserModel.fromJson(Map<String, dynamic> json, String id) {
    return UserModel(
      id: id,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: _parseRole(json['role']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // Convert UserModel to JSON Map for Firestore write operations
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static UserRole _parseRole(dynamic roleStr) {
    if (roleStr == null) return UserRole.parent;
    try {
      return UserRole.values.byName(roleStr.toString());
    } catch (_) {
      return UserRole.parent;
    }
  }

  // Copy with for immutable modifications
  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
