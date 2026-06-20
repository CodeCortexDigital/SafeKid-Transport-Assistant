class FeedbackModel {
  final String id;
  final String userId;
  final String userName;
  final int driverRating;
  final int safetyRating;
  final int punctualityRating;
  final String comments;
  final DateTime createdAt;

  // Legacy compatibility fields
  final String subject;
  final String description;
  final int rating;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.driverRating,
    required this.safetyRating,
    required this.punctualityRating,
    required this.comments,
    required this.createdAt,
    this.subject = '',
    this.description = '',
    int? rating,
  }) : this.rating = rating ?? ((driverRating + safetyRating + punctualityRating) / 3).round();

  factory FeedbackModel.fromJson(Map<String, dynamic> json, String docId) {
    final driver = json['driverRating'] is num ? (json['driverRating'] as num).toInt() : 5;
    final safety = json['safetyRating'] is num ? (json['safetyRating'] as num).toInt() : 5;
    final punctuality = json['punctualityRating'] is num ? (json['punctualityRating'] as num).toInt() : 5;
    
    return FeedbackModel(
      id: docId,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Parent',
      driverRating: driver,
      safetyRating: safety,
      punctualityRating: punctuality,
      comments: json['comments'] ?? json['description'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      rating: json['rating'] is num ? (json['rating'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'driverRating': driverRating,
      'safetyRating': safetyRating,
      'punctualityRating': punctualityRating,
      'comments': comments,
      'createdAt': createdAt.toIso8601String(),
      'subject': subject,
      'description': description,
      'rating': rating,
    };
  }

  FeedbackModel copyWith({
    String? id,
    String? userId,
    String? userName,
    int? driverRating,
    int? safetyRating,
    int? punctualityRating,
    String? comments,
    DateTime? createdAt,
    String? subject,
    String? description,
    int? rating,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      driverRating: driverRating ?? this.driverRating,
      safetyRating: safetyRating ?? this.safetyRating,
      punctualityRating: punctualityRating ?? this.punctualityRating,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      rating: rating ?? this.rating,
    );
  }
}
