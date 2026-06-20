import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/feedback_model.dart';
import '../providers/feedback_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/performance/driver_performance_service.dart';
import 'performance_gauge_widget.dart';
import 'glass_card.dart';

class DriverPerformanceCard extends StatelessWidget {
  const DriverPerformanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final feedbackProv = Provider.of<FeedbackProvider>(context);
    final attendanceProv = Provider.of<AttendanceProvider>(context);
    final students = attendanceProv.myStudents;

    return StreamBuilder<List<FeedbackModel>>(
      stream: feedbackProv.watchAllFeedback(),
      builder: (context, snapshot) {
        final feedback = snapshot.data ?? [];
        final metrics = DriverPerformanceService.calculate(
          feedback: feedback,
          students: students,
        );

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: AppTheme.accentLight, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Driver Performance Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 12, color: AppTheme.primaryLight),
                        SizedBox(width: 2),
                        Text(
                          'AI EVAL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Gauge Indicators Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  PerformanceGaugeWidget(
                    score: metrics.safetyScore,
                    label: 'Safety Score',
                  ),
                  PerformanceGaugeWidget(
                    score: metrics.performanceScore,
                    label: 'Performance Score',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 16),

              // Detail Row of Sub-scores
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSubMetric(
                    label: 'Rating',
                    value: '${metrics.averageRating.toStringAsFixed(1)} ★',
                    icon: Icons.star_rounded,
                    color: Colors.amber,
                  ),
                  _buildSubMetric(
                    label: 'Timeliness',
                    value: '${metrics.punctualityRate.toStringAsFixed(0)}%',
                    icon: Icons.access_time_filled_rounded,
                    color: AppTheme.accentLight,
                  ),
                  _buildSubMetric(
                    label: 'Boarding',
                    value: '${metrics.attendanceRate.toStringAsFixed(0)}%',
                    icon: Icons.how_to_reg_rounded,
                    color: AppTheme.success,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
