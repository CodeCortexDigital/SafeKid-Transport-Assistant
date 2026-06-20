enum UserRole {
  parent,
  driver,
  admin,
}

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final UserRole role;
  final String? profileImageUrl;
  final List<String>? emergencyContacts;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    this.emergencyContacts,
  });

  // Convert Firestore DocumentSnapshot / JSON Map to UserModel
  factory UserModel.fromJson(Map<String, dynamic> json, String id) {
    return UserModel(
      uid: id,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: _parseRole(json['role']),
      profileImageUrl: json['profileImageUrl'],
      emergencyContacts: json['emergencyContacts'] != null 
          ? List<String>.from(json['emergencyContacts']) 
          : null,
    );
  }

  // Convert UserModel to JSON Map for Firestore write operations
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'role': role.name,
      'profileImageUrl': profileImageUrl,
      'emergencyContacts': emergencyContacts,
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
    String? uid,
    String? email,
    String? name,
    String? phone,
    UserRole? role,
    String? profileImageUrl,
    List<String>? emergencyContacts,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }
}
