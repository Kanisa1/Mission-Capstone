import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../models/scan.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _apiService = ApiService();
  final _storageService = StorageService();

  List<Scan> _scans = [];
  List<Scan> _filteredScans = [];
  bool _isLoading = true;
  String? _selectedFilter;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScans() async {
    setState(() => _isLoading = true);

    try {
      final userId = _storageService.getUserId();
      final scans = await _apiService.getScans(userId: userId);

      if (mounted) {
        setState(() {
          _scans = scans;
          _filteredScans = scans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterScans(String? filterType) {
    setState(() {
      _selectedFilter = filterType;

      if (filterType == null || filterType == 'All') {
        _filteredScans = _scans;
      } else {
        _filteredScans = _scans.where((scan) {
          if (filterType == 'Verified') {
            return scan.verified;
          } else {
            return scan.mineral.toLowerCase() == filterType.toLowerCase();
          }
        }).toList();
      }
    });
  }

  void _searchScans(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredScans = _scans;
      } else {
        _filteredScans = _scans.where((scan) {
          return scan.mineral.toLowerCase().contains(query.toLowerCase()) ||
              scan.location.toLowerCase().contains(query.toLowerCase()) ||
              scan.scanId.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.06),
                AppTheme.backgroundColor,
              ],
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.softCardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan History',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Browse, filter and inspect all captured verification scans',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Search scans...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchScans('');
                                },
                              )
                            : null,
                      ),
                      onChanged: _searchScans,
                    ),
                  ],
                ),
              ),

              // Filter chips
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildFilterChip('All', null),
                    _buildFilterChip('Gold', 'gold'),
                    _buildFilterChip('Chalcopyrite', 'chalcopyrite'),
                    _buildFilterChip('Hematite', 'hematite'),
                    _buildFilterChip('Verified', 'Verified'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Scans list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredScans.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 80,
                                  color: AppTheme.textLight,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No scans found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadScans,
                            color: AppTheme.primaryColor,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _filteredScans.length,
                              itemBuilder: (context, index) {
                                return _buildScanCard(_filteredScans[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          _filterScans(selected ? value : null);
        },
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : AppTheme.textLight,
        ),
      ),
    );
  }

  Widget _buildScanCard(Scan scan) {
    final mineralColor = Color(
      AppConstants.mineralColors[scan.mineral.toLowerCase()] ?? 0xFFCCCCCC,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.06)),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showScanDetails(scan);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Mineral icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: mineralColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.diamond,
                    size: 32,
                    color: mineralColor,
                  ),
                ),

                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            scan.mineral,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (scan.verified)
                            const Icon(
                              Icons.verified,
                              size: 18,
                              color: AppTheme.successColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scan.location.replaceAll('_', ' '),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • HH:mm')
                            .format(scan.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),

                // Confidence badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        scan.confidencePercent,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textLight,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showScanDetails(Scan scan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildDetailItem('Mineral', scan.mineral),
                      _buildDetailItem('Confidence', scan.confidencePercent),
                      _buildDetailItem(
                          'Location', scan.location.replaceAll('_', ' ')),
                      _buildDetailItem(
                        'Date',
                        DateFormat('MMM dd, yyyy • HH:mm:ss')
                            .format(scan.timestamp),
                      ),
                      _buildDetailItem('Scan ID', scan.scanId),
                      _buildDetailItem(
                        'Verified',
                        scan.verified ? 'Yes' : 'No',
                        valueColor: scan.verified
                            ? AppTheme.successColor
                            : AppTheme.textSecondary,
                      ),

                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Export scan
                              },
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Export'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(
                                    color: AppTheme.primaryColor),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Share scan
                              },
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Share'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
      },
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
