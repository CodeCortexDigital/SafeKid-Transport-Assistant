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
  final String? customPickupTime;
  final String? customDropTime;
  final bool hasCustomTimings;
  final bool isReadyForPickup;
  final String? linkingOtp;
  final DateTime? linkingOtpExpires;
  final double monthlyFee;

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
    this.customPickupTime,
    this.customDropTime,
    this.hasCustomTimings = false,
    this.isReadyForPickup = false,
    this.linkingOtp,
    this.linkingOtpExpires,
    this.monthlyFee = 150.0,
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
      customPickupTime: json['customPickupTime'],
      customDropTime: json['customDropTime'],
      hasCustomTimings: json['hasCustomTimings'] ?? false,
      isReadyForPickup: json['isReadyForPickup'] ?? false,
      linkingOtp: json['linkingOtp'],
      linkingOtpExpires: json['linkingOtpExpires'] != null ? DateTime.tryParse(json['linkingOtpExpires'].toString()) : null,
      monthlyFee: (json['monthlyFee'] as num?)?.toDouble() ?? 150.0,
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
      'customPickupTime': customPickupTime,
      'customDropTime': customDropTime,
      'hasCustomTimings': hasCustomTimings,
      'isReadyForPickup': isReadyForPickup,
      'linkingOtp': linkingOtp,
      'linkingOtpExpires': linkingOtpExpires?.toIso8601String(),
      'monthlyFee': monthlyFee,
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
    String? customPickupTime,
    String? customDropTime,
    bool? hasCustomTimings,
    bool? isReadyForPickup,
    String? linkingOtp,
    DateTime? linkingOtpExpires,
    double? monthlyFee,
    bool clearOtp = false,
    bool clearCheckIn = false,
    bool clearCheckOut = false,
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
      lastCheckIn: clearCheckIn ? null : (lastCheckIn ?? this.lastCheckIn),
      lastCheckOut: clearCheckOut ? null : (lastCheckOut ?? this.lastCheckOut),
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      pickupPoint: pickupPoint ?? this.pickupPoint,
      dropPoint: dropPoint ?? this.dropPoint,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      dropLatitude: dropLatitude ?? this.dropLatitude,
      dropLongitude: dropLongitude ?? this.dropLongitude,
      customPickupTime: customPickupTime ?? this.customPickupTime,
      customDropTime: customDropTime ?? this.customDropTime,
      hasCustomTimings: hasCustomTimings ?? this.hasCustomTimings,
      isReadyForPickup: isReadyForPickup ?? this.isReadyForPickup,
      linkingOtp: clearOtp ? null : (linkingOtp ?? this.linkingOtp),
      linkingOtpExpires: clearOtp ? null : (linkingOtpExpires ?? this.linkingOtpExpires),
      monthlyFee: monthlyFee ?? this.monthlyFee,
    );
  }

  bool get isStudentReady {
    if (status == StudentStatus.absent) return false;
    if (DateTime.now().weekday == DateTime.sunday) return false;
    if (hasCustomTimings) {
      return _isCurrentTimeAtOrAfter(customPickupTime);
    }
    return isReadyForPickup;
  }

  bool _isCurrentTimeAtOrAfter(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return false;
    try {
      final cleanStr = timeStr.trim().toUpperCase();
      final parts = cleanStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      if (parts.length > 1) {
        final ampm = parts[1];
        if (ampm == 'PM' && hour < 12) {
          hour += 12;
        } else if (ampm == 'AM' && hour == 12) {
          hour = 0;
        }
      }

      final now = DateTime.now();
      final compareTime = DateTime(now.year, now.month, now.day, hour, minute);
      return now.isAfter(compareTime) || now.isAtSameMomentAs(compareTime);
    } catch (_) {
      return true; // fallback
    }
  }
}
