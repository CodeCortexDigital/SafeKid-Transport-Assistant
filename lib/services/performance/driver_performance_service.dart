import '../../models/feedback_model.dart';
import '../../models/student_model.dart';

class DriverPerformance {
  final double safetyScore;       // 0 - 100
  final double performanceScore;  // 0 - 100
  final double averageRating;     // 1.0 - 5.0
  final double punctualityRate;   // 0 - 100
  final double attendanceRate;    // 0 - 100

  DriverPerformance({
    required this.safetyScore,
    required this.performanceScore,
    required this.averageRating,
    required this.punctualityRate,
    required this.attendanceRate,
  });
}

class DriverPerformanceService {
  /// Computes performance metrics from parent feedback and route attendance data.
  static DriverPerformance calculate({
    required List<FeedbackModel> feedback,
    required List<StudentModel> students,
  }) {
    final double attendanceRate = _calculateAttendance(students);

    if (feedback.isEmpty) {
      // Default maximum scores when no feedback has been submitted yet
      const double defaultRating = 5.0;
      const double defaultSafety = 100.0;
      const double defaultPunctuality = 100.0;
      
      // 35% Rating, 35% Punctuality, 30% Attendance
      final double defaultPerformance = (defaultRating / 5.0 * 35.0) + 
                                        (defaultPunctuality * 0.35) + 
                                        (attendanceRate * 0.30);

      return DriverPerformance(
        safetyScore: defaultSafety,
        performanceScore: defaultPerformance,
        averageRating: defaultRating,
        punctualityRate: defaultPunctuality,
        attendanceRate: attendanceRate,
      );
    }

    double totalDriverRating = 0.0;
    double totalSafetyRating = 0.0;
    double totalPunctualityRating = 0.0;

    for (var f in feedback) {
      totalDriverRating += f.driverRating;
      totalSafetyRating += f.safetyRating;
      totalPunctualityRating += f.punctualityRating;
    }

    final double count = feedback.length.toDouble();
    final double avgDriverRating = totalDriverRating / count;
    final double avgSafety = totalSafetyRating / count;
    final double avgPunctuality = totalPunctualityRating / count;

    final double safetyScore = (avgSafety / 5.0) * 100.0;
    final double punctualityRate = (avgPunctuality / 5.0) * 100.0;

    // Performance Score Formula:
    // 35% Driver star rating, 35% Punctuality rate, 30% Attendance completion rate
    final double performanceScore = ((avgDriverRating / 5.0) * 35.0) +
                                    (punctualityRate * 0.35) +
                                    (attendanceRate * 0.30);

    return DriverPerformance(
      safetyScore: safetyScore,
      performanceScore: performanceScore,
      averageRating: avgDriverRating,
      punctualityRate: punctualityRate,
      attendanceRate: attendanceRate,
    );
  }

  static double _calculateAttendance(List<StudentModel> students) {
    if (students.isEmpty) return 100.0;
    // Boarded students are those currently In Transit or already At School
    final boardedCount = students.where((s) => 
      s.status == StudentStatus.inTransit || 
      s.status == StudentStatus.atSchool
    ).length;
    return (boardedCount / students.length.toDouble()) * 100.0;
  }
}
