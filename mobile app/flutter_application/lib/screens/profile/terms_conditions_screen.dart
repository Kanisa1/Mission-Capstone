import 'package:flutter/material.dart';
import '../../config/theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms & Conditions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: February 22, 2026',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Acceptance of Terms',
              'By accessing and using MineralTrace, you agree to be bound by these Terms and Conditions. If you do not agree with any part of these terms, you may not use our service.',
            ),
            _buildSection(
              '2. Use of Service',
              'MineralTrace is designed for mineral identification and traceability. You agree to use the service only for lawful purposes and in accordance with these Terms.',
            ),
            _buildSection(
              '3. User Accounts',
              'You are responsible for maintaining the confidentiality of your account credentials. You agree to accept responsibility for all activities that occur under your account.',
            ),
            _buildSection(
              '4. Data Collection',
              'We collect and process scan data, including images, audio samples, and chemical analysis results. This data is used to improve our AI models and provide better service.',
            ),
            _buildSection(
              '5. Accuracy Disclaimer',
              'While our system achieves 88.5% accuracy, mineral identification results should be verified by qualified professionals before making critical decisions.',
            ),
            _buildSection(
              '6. Intellectual Property',
              'All content, features, and functionality of MineralTrace are owned by Mission Capstone and protected by international copyright, trademark, and other intellectual property laws.',
            ),
            _buildSection(
              '7. Limitation of Liability',
              'MineralTrace shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the service.',
            ),
            _buildSection(
              '8. Changes to Terms',
              'We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the modified terms.',
            ),
            _buildSection(
              '9. Contact Information',
              'For questions about these Terms, please contact us at legal@mineraltrace.com',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'By using MineralTrace, you acknowledge that you have read and understood these terms.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
