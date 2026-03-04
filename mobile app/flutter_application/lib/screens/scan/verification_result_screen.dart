import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/verification_result.dart';
import '../../models/prediction_result.dart';

class VerificationResultScreen extends StatelessWidget {
  final VerificationResult verification;
  final PredictionResult prediction;

  const VerificationResultScreen({super.key, required this.verification, required this.prediction});

  @override
  Widget build(BuildContext context) {
    final success = verification.isAuthentic;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Verification Result'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      success ? Icons.check_circle : Icons.error_outline,
                      size: 84,
                      color: success ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      success ? 'Sample Verified' : 'Verification Failed',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      verification.message ?? (success ? 'Sample appears authentic' : 'No matching fingerprint found'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text('Match score: ${verification.matchScorePercent}'),
                    if (verification.matchedFingerprintId != null) ...[
                      const SizedBox(height: 8),
                      Text('Matched fingerprint: ${verification.matchedFingerprintId}'),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Prediction summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Prediction Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Mineral: ${prediction.predictedMineral}'),
                    const SizedBox(height: 4),
                    Text('Confidence: ${prediction.confidencePercent}'),
                    const SizedBox(height: 8),
                    if (prediction.scanId != null) Text('Scan ID: ${prediction.scanId}'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  child: Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
