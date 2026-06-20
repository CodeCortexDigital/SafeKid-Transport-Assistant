class ScanLogModel {
  final String id;
  final String studentId;
  final String scannerId;
  final String scanType; // checkIn, checkOut
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String status; // success, failure

  ScanLogModel({
    required this.id,
    required this.studentId,
    required this.scannerId,
    required this.scanType,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  factory ScanLogModel.fromJson(Map<String, dynamic> json, String docId) {
    return ScanLogModel(
      id: docId,
      studentId: json['studentId'] ?? '',
      scannerId: json['scannerId'] ?? '',
      scanType: json['scanType'] ?? 'checkIn',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'success',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'scannerId': scannerId,
      'scanType': scanType,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
    };
  }

  ScanLogModel copyWith({
    String? id,
    String? studentId,
    String? scannerId,
    String? scanType,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? status,
  }) {
    return ScanLogModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      scannerId: scannerId ?? this.scannerId,
      scanType: scanType ?? this.scanType,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
    );
  }
}
