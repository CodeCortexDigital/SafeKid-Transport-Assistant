enum TripStatus {
  scheduled,
  active,
  completed,
  cancelled,
}

class TripModel {
  final String id;
  final String vehicleId;
  final String driverId;
  final String routeName;
  final List<String> studentIds;
  final double currentLatitude;
  final double currentLongitude;
  final String etaMinutes;
  final TripStatus status;
  final DateTime? startTime;
  final DateTime? endTime;

  TripModel({
    required this.id,
    required this.vehicleId,
    required this.driverId,
    required this.routeName,
    required this.studentIds,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.etaMinutes,
    required this.status,
    this.startTime,
    this.endTime,
  });

  factory TripModel.fromJson(Map<String, dynamic> json, String docId) {
    return TripModel(
      id: docId,
      vehicleId: json['vehicleId'] ?? '',
      driverId: json['driverId'] ?? '',
      routeName: json['routeName'] ?? '',
      studentIds: json['studentIds'] != null ? List<String>.from(json['studentIds']) : [],
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble() ?? 0.0,
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble() ?? 0.0,
      etaMinutes: json['etaMinutes']?.toString() ?? '--',
      status: _parseStatus(json['status']),
      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime'].toString()) : null,
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleId': vehicleId,
      'driverId': driverId,
      'routeName': routeName,
      'studentIds': studentIds,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'etaMinutes': etaMinutes,
      'status': status.name,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  static TripStatus _parseStatus(dynamic statusStr) {
    if (statusStr == null) return TripStatus.scheduled;
    try {
      return TripStatus.values.byName(statusStr.toString());
    } catch (_) {
      return TripStatus.scheduled;
    }
  }

  TripModel copyWith({
    String? id,
    String? vehicleId,
    String? driverId,
    String? routeName,
    List<String>? studentIds,
    double? currentLatitude,
    double? currentLongitude,
    String? etaMinutes,
    TripStatus? status,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return TripModel(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      driverId: driverId ?? this.driverId,
      routeName: routeName ?? this.routeName,
      studentIds: studentIds ?? this.studentIds,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
