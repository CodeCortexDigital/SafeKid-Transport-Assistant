class VehicleModel {
  final String id;
  final String vehicleNumber;
  final String model;
  final int capacity;
  final String driverId;
  final String status; // active, inactive
  final double currentLatitude;
  final double currentLongitude;
  final DateTime lastUpdated;

  VehicleModel({
    required this.id,
    required this.vehicleNumber,
    required this.model,
    required this.capacity,
    required this.driverId,
    required this.status,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.lastUpdated,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json, String documentId) {
    return VehicleModel(
      id: documentId,
      vehicleNumber: json['vehicleNumber'] ?? '',
      model: json['model'] ?? '',
      capacity: json['capacity'] is num ? (json['capacity'] as num).toInt() : 0,
      driverId: json['driverId'] ?? '',
      status: json['status'] ?? 'inactive',
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble() ?? 0.0,
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleNumber': vehicleNumber,
      'model': model,
      'capacity': capacity,
      'driverId': driverId,
      'status': status,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  VehicleModel copyWith({
    String? id,
    String? vehicleNumber,
    String? model,
    int? capacity,
    String? driverId,
    String? status,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? lastUpdated,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      model: model ?? this.model,
      capacity: capacity ?? this.capacity,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
