enum StudentStatus {
  home,
  inTransit,
  atSchool,
  absent,
}

class StudentModel {
  final String id;
  final String name;
  final String className;
  final String section;
  final String schoolName;
  final String parentUid;
  final String qrCodeData;
  final StudentStatus status;
  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;

  StudentModel({
    required this.id,
    required this.name,
    required this.className,
    required this.section,
    required this.schoolName,
    required this.parentUid,
    required this.qrCodeData,
    this.status = StudentStatus.home,
    this.lastCheckIn,
    this.lastCheckOut,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json, String documentId) {
    return StudentModel(
      id: documentId,
      name: json['name'] ?? '',
      className: json['className'] ?? '',
      section: json['section'] ?? '',
      schoolName: json['schoolName'] ?? '',
      parentUid: json['parentUid'] ?? '',
      qrCodeData: json['qrCodeData'] ?? '',
      status: _parseStatus(json['status']),
      lastCheckIn: json['lastCheckIn'] != null ? DateTime.tryParse(json['lastCheckIn'].toString()) : null,
      lastCheckOut: json['lastCheckOut'] != null ? DateTime.tryParse(json['lastCheckOut'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'className': className,
      'section': section,
      'schoolName': schoolName,
      'parentUid': parentUid,
      'qrCodeData': qrCodeData,
      'status': status.name,
      'lastCheckIn': lastCheckIn?.toIso8601String(),
      'lastCheckOut': lastCheckOut?.toIso8601String(),
    };
  }

  static StudentStatus _parseStatus(dynamic statusStr) {
    if (statusStr == null) return StudentStatus.home;
    try {
      return StudentStatus.values.byName(statusStr.toString());
    } catch (_) {
      return StudentStatus.home;
    }
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? className,
    String? section,
    String? schoolName,
    String? parentUid,
    String? qrCodeData,
    StudentStatus? status,
    DateTime? lastCheckIn,
    DateTime? lastCheckOut,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      className: className ?? this.className,
      section: section ?? this.section,
      schoolName: schoolName ?? this.schoolName,
      parentUid: parentUid ?? this.parentUid,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      status: status ?? this.status,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      lastCheckOut: lastCheckOut ?? this.lastCheckOut,
    );
  }
}
