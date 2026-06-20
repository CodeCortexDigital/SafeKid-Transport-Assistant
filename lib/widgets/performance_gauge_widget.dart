import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class PerformanceGaugeWidget extends StatelessWidget {
  final double score; // 0 to 100
  final String label;
  final double size;

  const PerformanceGaugeWidget({
    super.key,
    required this.score,
    required this.label,
    this.size = 90.0,
  });

  Color _getScoreColor(double score) {
    if (score >= 85.0) {
      return AppTheme.success; // emerald green
    } else if (score >= 70.0) {
      return AppTheme.warning; // amber orange
    } else {
      return AppTheme.error;   // crimson red
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetColor = _getScoreColor(score);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background track
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.04)),
                ),
              ),
              // Animated progress ring
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: score / 100.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, animValue, _) {
                  return Positioned.fill(
                    child: CircularProgressIndicator(
                      value: animValue,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      valueColor: AlwaysStoppedAnimation<Color>(targetColor),
                    ),
                  );
                },
              ),
              // Centered value text with pulsing effect
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
