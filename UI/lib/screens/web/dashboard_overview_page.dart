import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../constants/api_config.dart';
import '../../services/api_service.dart';

class DashboardOverviewPage extends StatefulWidget {
  const DashboardOverviewPage({super.key});

  @override
  State<DashboardOverviewPage> createState() => _DashboardOverviewPageState();
}

class _DashboardOverviewPageState extends State<DashboardOverviewPage> {
  late final ApiService _apiService;
  Map<String, dynamic>? _stats;
  List<dynamic>? _recentVerifications;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ApiConfig.defaultBaseUrl);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statsResponse = await _apiService.getStats();
      final verificationsResponse = await _apiService.getVerifications(limit: 10);

      setState(() {
        _stats = statsResponse;
        _recentVerifications = verificationsResponse['verifications'] as List<dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error loading data: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final totalScans = _stats?['total_scans'] ?? 0;
    final verified = _stats?['verified'] ?? 0;
    final notVerified = _stats?['not_verified'] ?? 0;
    final byMineral = _stats?['by_mineral'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Scans',
                  '$totalScans',
                  Icons.camera_alt_outlined,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Verified',
                  '$verified',
                  Icons.check_circle_outline,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Not Verified',
                  '$notVerified',
                  Icons.cancel_outlined,
                  AppColors.error,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Mineral Types',
                  '${byMineral.length}',
                  Icons.diamond_outlined,
                  AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRecentActivityTable(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const Spacer(),
                const Icon(Icons.trending_up, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityTable() {
    if (_recentVerifications == null || _recentVerifications!.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No verification records yet',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Sample ID', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Site', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Mineral', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Officer', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ..._recentVerifications!.map((v) {
                  final sampleId = v['id']?.toString() ?? 'N/A';
                  final timestamp = v['timestamp']?.toString() ?? 'N/A';
                  final site = v['site']?.toString() ?? 'N/A';
                  final mineral = v['mineral']?.toString() ?? 'N/A';
                  final userName = v['user_name']?.toString() ?? 'Unknown';
                  final status = v['status']?.toString() ?? 'verified';
                  
                  return _buildTableRow(
                    sampleId,
                    _formatTimestamp(timestamp),
                    site,
                    mineral,
                    userName,
                    status,
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      // For very recent times (< 1 hour), show relative time
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} min ago';
      } 
      // For today, show time
      else if (diff.inHours < 24 && dt.day == now.day) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      } 
      // For older dates, show full date and time
      else {
        final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1];
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$month ${dt.day}, $hour:$minute';
      }
    } catch (e) {
      return timestamp;
    }
  }

  TableRow _buildTableRow(String sampleId, String time, String site, String mineral, String officer, String status) {
    // Determine status color and text
    Color statusColor;
    String statusText;
    if (status == 'verified') {
      statusColor = AppColors.success;
      statusText = 'Verified';
    } else if (status == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending';
    } else {
      statusColor = AppColors.error;
      statusText = 'Not Verified';
    }
    
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(sampleId, overflow: TextOverflow.ellipsis),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(time),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(site),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(mineral),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(officer),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
