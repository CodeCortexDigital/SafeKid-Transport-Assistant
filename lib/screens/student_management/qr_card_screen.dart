import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/student_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_saver.dart';

class QrCardScreen extends StatelessWidget {
  const QrCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve student argument passed during navigation
    final student = ModalRoute.of(context)?.settings.arguments as StudentModel?;
    final boundaryKey = GlobalKey();

    if (student == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Safety Pass'),
        ),
        body: const Center(
          child: Text(
            'Error: No student data provided.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final String qrContent = '${student.id}|${student.name}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          '${student.name}\'s Pass',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Repaint boundary surrounds the card we want to capture
              RepaintBoundary(
                key: boundaryKey,
                child: _buildPassCard(context, student, qrContent),
              ),
              const SizedBox(height: 36),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveQrImage(context, boundaryKey, student.name),
                      icon: const Icon(Icons.download_rounded, color: AppTheme.textPrimary),
                      label: const Text('Save Pass'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareQrImage(context, boundaryKey, student.name),
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      label: const Text('Share Pass'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Let the school bus driver or gate administrator scan this pass QR code for live check-in and transit updates.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PASS CARD BUILDER ---
  Widget _buildPassCard(BuildContext context, StudentModel student, String qrContent) {
    return Container(
      // Keep card styling fully self-contained for repaint capture
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SafeKid Transit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryLight.withOpacity(0.3), width: 1),
                ),
                child: const Text(
                  'Safety Pass',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // QR Code Frame
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: qrContent,
              version: QrVersions.auto,
              size: 200.0,
              gapless: false,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F172A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Student Details Block
          Text(
            student.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            student.schoolName,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // Detail Grid Rows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCardDetail('Grade/Class', student.className),
              _buildCardDetail('Section', student.section),
              _buildCardDetail('Status', student.status == StudentStatus.home ? 'Home' : student.status == StudentStatus.atSchool ? 'At School' : 'In Transit'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardDetail(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  // --- ACTIONS: SAVE IMAGE ---
  Future<void> _saveQrImage(BuildContext context, GlobalKey boundaryKey, String studentName) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) throw Exception('Image capture failed.');

      final filename = 'SafeKid_${studentName.replaceAll(' ', '_')}_Pass.png';
      await saveFileBytes(pngBytes, filename);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb
                ? 'Safety Pass image downloaded to browser!'
                : 'Safety Pass saved as $filename'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save pass: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // --- ACTIONS: SHARE PASS ---
  Future<void> _shareQrImage(BuildContext context, GlobalKey boundaryKey, String studentName) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) throw Exception('Image capture failed.');

      final xFile = XFile.fromData(
        pngBytes,
        name: 'SafeKid_${studentName.replaceAll(' ', '_')}_Pass.png',
        mimeType: 'image/png',
      );

      await Share.shareXFiles(
        [xFile],
        text: 'Here is the SafeKid Transit Pass for $studentName.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share pass: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
