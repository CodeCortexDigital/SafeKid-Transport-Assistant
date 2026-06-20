class FeedbackModel {
  final String id;
  final String userId;
  final String subject;
  final String description;
  final int rating; // e.g. 1 to 5 stars
  final DateTime createdAt;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.subject,
    required this.description,
    required this.rating,
    required this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json, String docId) {
    return FeedbackModel(
      id: docId,
      userId: json['userId'] ?? '',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      rating: json['rating'] is num ? (json['rating'] as num).toInt() : 5,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'subject': subject,
      'description': description,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  FeedbackModel copyWith({
    String? id,
    String? userId,
    String? subject,
    String? description,
    int? rating,
    DateTime? createdAt,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
