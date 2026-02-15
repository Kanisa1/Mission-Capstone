import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../constants/api_config.dart';
import '../../services/api_service.dart';

class VerificationsPage extends StatefulWidget {
  const VerificationsPage({super.key});

  @override
  State<VerificationsPage> createState() => _VerificationsPageState();
}

class _VerificationsPageState extends State<VerificationsPage> {
  late final ApiService _apiService;
  String _filterSite = 'all';
  List<dynamic>? _verifications;
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
      final response = await _apiService.getVerifications(
        site: _filterSite == 'all' ? null : _filterSite,
      );

      setState(() {
        _verifications = response['verifications'] as List<dynamic>?;
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

    if (_verifications == null || _verifications!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No verification records yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search verifications...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _filterSite,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Sites')),
                  DropdownMenuItem(value: 'Central_Equatoria', child: Text('Central Equatoria')),
                  DropdownMenuItem(value: 'Kapoeta_East', child: Text('Kapoeta East')),
                  DropdownMenuItem(value: 'Yei_River', child: Text('Yei River')),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterSite = value!;
                  });
                  _loadData();
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Sample ID')),
                  DataColumn(label: Text('Timestamp')),
                  DataColumn(label: Text('Site')),
                  DataColumn(label: Text('Mineral')),
                  DataColumn(label: Text('Officer')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Confidence')),
                ],
                rows: _verifications!.map((record) {
                  final sampleId = record['id']?.toString() ?? 'N/A';
                  final timestamp = record['timestamp']?.toString() ?? '';
                  final site = record['site']?.toString() ?? 'N/A';
                  final mineral = record['mineral']?.toString() ?? 'N/A';
                  final userName = record['user_name']?.toString() ?? 'Unknown';
                  final status = record['status']?.toString() ?? 'verified';
                  final confidence = record['confidence'] as num?;
                  
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

                  return DataRow(
                    cells: [
                      DataCell(Text(sampleId)),
                      DataCell(Text(_formatTimestamp(timestamp))),
                      DataCell(Text(site)),
                      DataCell(Text(mineral)),
                      DataCell(Text(userName)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          confidence != null ? '${(confidence * 100).toStringAsFixed(1)}%' : 'N/A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: confidence != null && confidence >= 0.8 ? AppColors.success : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('MMM dd, HH:mm').format(dt);
    } catch (e) {
      return timestamp;
    }
  }
}
