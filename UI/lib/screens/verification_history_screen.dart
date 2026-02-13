import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../models/verification_record.dart';
import 'verification_result_screen.dart';

class VerificationHistoryScreen extends StatelessWidget {
  const VerificationHistoryScreen({super.key});

  // Mock data for verification history
  List<VerificationRecord> _getMockHistory() {
    return [
      VerificationRecord(
        id: '1',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        userId: '1',
        userName: 'John Inspector',
        mineralType: MineralType.gold,
        location: 'Central Equatoria',
        miningSite: 'Site A',
        status: VerificationStatus.verified,
        confidenceScore: 0.92,
        notes: 'Sample from mine site A',
      ),
      VerificationRecord(
        id: '2',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        userId: '1',
        userName: 'John Inspector',
        mineralType: MineralType.chalcopyrite,
        location: 'Kapoeta East',
        miningSite: 'Site B',
        status: VerificationStatus.verified,
        confidenceScore: 0.88,
      ),
      VerificationRecord(
        id: '3',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        userId: '1',
        userName: 'John Inspector',
        mineralType: MineralType.hematite,
        location: 'Yei River',
        miningSite: 'Site C',
        status: VerificationStatus.notVerified,
        confidenceScore: 0.45,
        notes: 'Suspicious origin',
      ),
      VerificationRecord(
        id: '4',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        userId: '1',
        userName: 'John Inspector',
        mineralType: MineralType.gold,
        location: 'Central Equatoria',
        miningSite: 'Site A',
        status: VerificationStatus.verified,
        confidenceScore: 0.95,
      ),
      VerificationRecord(
        id: '5',
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
        userId: '1',
        userName: 'John Inspector',
        mineralType: MineralType.chalcopyrite,
        location: 'Kapoeta East',
        miningSite: 'Site B',
        status: VerificationStatus.verified,
        confidenceScore: 0.91,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final history = _getMockHistory();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verification History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${history.length} verification records',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: history.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        return _buildHistoryCard(context, history[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, VerificationRecord record) {
    final isVerified = record.status == VerificationStatus.verified;
    final statusColor = isVerified ? AppColors.success : AppColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VerificationResultScreen(record: record),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          record.statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Confidence score
                  Text(
                    '${(record.confidenceScore * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Mineral type
              Row(
                children: [
                  const Icon(
                    Icons.diamond_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    record.mineralName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Location
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    record.location,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Timestamp
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd, yyyy - HH:mm').format(record.timestamp),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notes_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          record.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No verification history',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your verification records will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
