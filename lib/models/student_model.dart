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
  final String parentName;
  final String parentPhone;
  final String pickupPoint;
  final String dropPoint;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropLatitude;
  final double? dropLongitude;

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
    this.parentName = '',
    this.parentPhone = '',
    this.pickupPoint = '',
    this.dropPoint = '',
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropLatitude,
    this.dropLongitude,
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
      parentName: json['parentName'] ?? '',
      parentPhone: json['parentPhone'] ?? '',
      pickupPoint: json['pickupPoint'] ?? '',
      dropPoint: json['dropPoint'] ?? '',
      pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
      pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
      dropLatitude: (json['dropLatitude'] as num?)?.toDouble(),
      dropLongitude: (json['dropLongitude'] as num?)?.toDouble(),
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
      'parentName': parentName,
      'parentPhone': parentPhone,
      'pickupPoint': pickupPoint,
      'dropPoint': dropPoint,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'dropLatitude': dropLatitude,
      'dropLongitude': dropLongitude,
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
    String? parentName,
    String? parentPhone,
    String? pickupPoint,
    String? dropPoint,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropLatitude,
    double? dropLongitude,
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
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      pickupPoint: pickupPoint ?? this.pickupPoint,
      dropPoint: dropPoint ?? this.dropPoint,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      dropLatitude: dropLatitude ?? this.dropLatitude,
      dropLongitude: dropLongitude ?? this.dropLongitude,
    );
  }
}
