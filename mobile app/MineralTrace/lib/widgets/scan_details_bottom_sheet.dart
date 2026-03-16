import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/scan.dart';

class ScanDetailsBottomSheet extends StatelessWidget {
  final Scan scan;

  const ScanDetailsBottomSheet({
    super.key,
    required this.scan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with mineral name
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.diamond,
                          color: AppTheme.accentColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scan.mineral,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (scan.verified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.verified_user,
                                          size: 12,
                                          color: AppTheme.successColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Verified',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.successColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Confidence & Location Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          'Confidence',
                          scan.confidencePercent,
                          Icons.analytics,
                          AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'Accuracy',
                          '${(scan.confidence * 100).toStringAsFixed(1)}%',
                          Icons.check_circle,
                          AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location
                  _buildInfoCard(
                    'Location',
                    scan.location.replaceAll('_', ' ').toUpperCase(),
                    Icons.location_on,
                    AppTheme.primaryColor,
                  ),

                  const SizedBox(height: 24),

                  // Modalities Section
                  const Text(
                    'Modalities Used',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildModalitiesList(),

                  const SizedBox(height: 28),

                  // Images Section
                  if (scan.imageUrl != null && scan.imageUrl!.isNotEmpty) ...[
                    const Text(
                      'Scan Images',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildImageGallery(),
                    const SizedBox(height: 28),
                  ],

                  // Fingerprint Data Section
                  if (scan.fingerprint != null &&
                      scan.fingerprint!.isNotEmpty) ...[
                    const Text(
                      'Analysis Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFingerprintData(),
                    const SizedBox(height: 28),
                  ],

                  // Detailed Information
                  const Text(
                    'Scan Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailItem('Scan ID', scan.scanId),
                  _buildDetailItem('User ID', scan.userId),
                  _buildDetailItem(
                    'Timestamp',
                    DateFormat('MMM dd, yyyy • HH:mm:ss')
                        .format(scan.timestamp),
                  ),
                  _buildDetailItem(
                    'Date Only',
                    DateFormat('EEEE, MMMM dd, yyyy').format(scan.timestamp),
                  ),

                  const SizedBox(height: 28),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Scan ${scan.scanId} exported successfully!'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModalitiesList() {
    final modalities = <Map<String, dynamic>>[];

    if (scan.imageUrl != null && scan.imageUrl!.isNotEmpty) {
      modalities.add({
        'name': 'Image Capture',
        'icon': Icons.image,
        'color': AppTheme.accentColor,
      });
    }

    if (scan.audioUrl != null && scan.audioUrl!.isNotEmpty) {
      modalities.add({
        'name': 'Audio Recording',
        'icon': Icons.mic,
        'color': const Color(0xFFFF6B6B),
      });
    }

    if (scan.fingerprint != null && scan.fingerprint!.isNotEmpty) {
      modalities.add({
        'name': 'Data Analysis',
        'icon': Icons.analytics,
        'color': const Color(0xFF4ECDC4),
      });
    }

    if (modalities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.textLight.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No modalities recorded',
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: modalities
          .map((modality) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (modality['color'] as Color).withValues(alpha: 0.08),
                    border: Border.all(
                      color:
                          (modality['color'] as Color).withValues(alpha: 0.15),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        modality['icon'] as IconData,
                        color: modality['color'] as Color,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        modality['name'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: modality['color'] as Color,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (modality['color'] as Color).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: modality['color'] as Color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildImageGallery() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.textLight.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          if (scan.imageUrl != null && scan.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: scan.imageUrl!,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 300,
                  color: AppTheme.textLight.withValues(alpha: 0.1),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: AppTheme.textLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: AppTheme.textLight,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Scan Image • ${DateTime.now().difference(scan.timestamp).inHours} hours ago',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintData() {
    final fingerprintData = scan.fingerprint ?? {};
    final items = fingerprintData.entries.toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.textLight.withValues(alpha: 0.03),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .take(5)
            .map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.textLight.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Courier',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
