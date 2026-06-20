enum RideStatus {
  scheduled,
  active,
  completed,
  cancelled,
}

class RideModel {
  final String id;
  final String driverUid;
  final String routeName;
  final List<String> studentIds;
  final double currentLatitude;
  final double currentLongitude;
  final RideStatus status;
  final String etaMinutes;
  final DateTime? startTime;
  final DateTime? endTime;

  RideModel({
    required this.id,
    required this.driverUid,
    required this.routeName,
    required this.studentIds,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.status,
    required this.etaMinutes,
    this.startTime,
    this.endTime,
  });

  factory RideModel.fromJson(Map<String, dynamic> json, String docId) {
    return RideModel(
      id: docId,
      driverUid: json['driverUid'] ?? '',
      routeName: json['routeName'] ?? '',
      studentIds: json['studentIds'] != null ? List<String>.from(json['studentIds']) : [],
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble() ?? 0.0,
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(json['status']),
      etaMinutes: json['etaMinutes']?.toString() ?? '--',
      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime'].toString()) : null,
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverUid': driverUid,
      'routeName': routeName,
      'studentIds': studentIds,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'status': status.name,
      'etaMinutes': etaMinutes,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  static RideStatus _parseStatus(dynamic statusStr) {
    if (statusStr == null) return RideStatus.scheduled;
    try {
      return RideStatus.values.byName(statusStr.toString());
    } catch (_) {
      return RideStatus.scheduled;
    }
  }

  RideModel copyWith({
    String? id,
    String? driverUid,
    String? routeName,
    List<String>? studentIds,
    double? currentLatitude,
    double? currentLongitude,
    RideStatus? status,
    String? etaMinutes,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return RideModel(
      id: id ?? this.id,
      driverUid: driverUid ?? this.driverUid,
      routeName: routeName ?? this.routeName,
      studentIds: studentIds ?? this.studentIds,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      status: status ?? this.status,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
