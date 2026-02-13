import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../models/verification_record.dart';
import 'verification_result_screen.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  String _filterStatus = 'all';
  String _searchQuery = '';

  // Mock data for audit trail (includes multiple users)
  List<VerificationRecord> _getMockAuditData() {
    return [
      VerificationRecord(
        id: '1',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        userId: '1',
        userName: 'John Inspector',
        mineralType: MineralType.gold,
        location: 'Central Equatoria',
        miningSite: 'Site A',
        status: VerificationStatus.verified,
        confidenceScore: 0.92,
      ),
      VerificationRecord(
        id: '2',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        userId: '2',
        userName: 'Sarah Field Officer',
        mineralType: MineralType.chalcopyrite,
        location: 'Kapoeta East',
        miningSite: 'Site B',
        status: VerificationStatus.verified,
        confidenceScore: 0.88,
      ),
      VerificationRecord(
        id: '3',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        userId: '3',
        userName: 'Mike Verifier',
        mineralType: MineralType.hematite,
        location: 'Yei River',
        miningSite: 'Site C',
        status: VerificationStatus.notVerified,
        confidenceScore: 0.42,
        notes: 'Suspicious origin detected',
      ),
      VerificationRecord(
        id: '4',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
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
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
        userId: '4',
        userName: 'Lisa Compliance',
        mineralType: MineralType.chalcopyrite,
        location: 'Kapoeta East',
        miningSite: 'Site B',
        status: VerificationStatus.verified,
        confidenceScore: 0.89,
      ),
      VerificationRecord(
        id: '6',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        userId: '2',
        userName: 'Sarah Field Officer',
        mineralType: MineralType.gold,
        location: 'Central Equatoria',
        miningSite: 'Site A',
        status: VerificationStatus.notVerified,
        confidenceScore: 0.38,
        notes: 'Failed acoustic fingerprint match',
      ),
      VerificationRecord(
        id: '7',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        userId: '3',
        userName: 'Mike Verifier',
        mineralType: MineralType.hematite,
        location: 'Yei River',
        miningSite: 'Site C',
        status: VerificationStatus.verified,
        confidenceScore: 0.91,
      ),
    ];
  }

  List<VerificationRecord> _getFilteredRecords() {
    var records = _getMockAuditData();

    // Filter by status
    if (_filterStatus != 'all') {
      final status = _filterStatus == 'verified'
          ? VerificationStatus.verified
          : VerificationStatus.notVerified;
      records = records.where((r) => r.status == status).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      records = records.where((r) {
        final query = _searchQuery.toLowerCase();
        return r.userName.toLowerCase().contains(query) ||
            r.location.toLowerCase().contains(query) ||
            r.mineralName.toLowerCase().contains(query);
      }).toList();
    }

    return records;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _getFilteredRecords();
    final allRecords = _getMockAuditData();
    final verifiedCount = allRecords.where((r) => r.status == VerificationStatus.verified).length;
    final notVerifiedCount = allRecords.where((r) => r.status == VerificationStatus.notVerified).length;

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
                    'Audit Trail',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'System-wide verification records',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Statistics cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          allRecords.length.toString(),
                          AppColors.primary,
                          Icons.list_alt,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Verified',
                          verifiedCount.toString(),
                          AppColors.success,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Failed',
                          notVerifiedCount.toString(),
                          AppColors.error,
                          Icons.cancel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by user, location, or mineral...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Verified', 'verified'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Not Verified', 'notVerified'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Records list
            Expanded(
              child: filteredRecords.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        return _buildAuditCard(context, filteredRecords[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildAuditCard(BuildContext context, VerificationRecord record) {
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
                      horizontal: 10,
                      vertical: 5,
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
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          record.statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(record.confidenceScore * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // User info
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      record.userName[0],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.userName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'User ID: ${record.userId}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              
              // Mineral and location
              Row(
                children: [
                  Icon(
                    Icons.diamond_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    record.mineralName,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.location,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              
              // Timestamp
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM dd, yyyy - HH:mm').format(record.timestamp),
                    style: TextStyle(
                      fontSize: 13,
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
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          record.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
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
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No records found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
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
