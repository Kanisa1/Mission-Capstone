import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../models/verification_record.dart';

class VerificationResultScreen extends StatelessWidget {
  final VerificationRecord record;

  const VerificationResultScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final isVerified = record.status == VerificationStatus.verified;
    final statusColor = isVerified ? AppColors.success : AppColors.error;
    final statusIcon = isVerified ? Icons.check_circle : Icons.cancel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Result'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    size: 80,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Status text
              Text(
                record.statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 32),

              // Result card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verification Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 24),
                      
                      _buildDetailRow(
                        'Mineral Type',
                        record.mineralName,
                        Icons.diamond_outlined,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDetailRow(
                        'Location',
                        record.location,
                        Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDetailRow(
                        'Timestamp',
                        DateFormat('MMM dd, yyyy - HH:mm').format(record.timestamp),
                        Icons.access_time,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDetailRow(
                        'Verified By',
                        record.userName,
                        Icons.person_outline,
                      ),
                      
                      if (record.notes != null && record.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          'Notes',
                          record.notes!,
                          Icons.notes_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confidence score card
              Card(
                color: statusColor.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Confidence Score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(record.confidenceScore * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: record.confidenceScore,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isVerified
                            ? 'High confidence - Sample verified'
                            : 'Low confidence - Sample not verified',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Back button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text(
                  'Back to Scan',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
