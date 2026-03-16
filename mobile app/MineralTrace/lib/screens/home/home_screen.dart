import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/scan.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/home_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/mineral_card.dart';
import '../../widgets/map_embed_widget.dart';
import '../profile/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  List<Scan> _recentScans = [];
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;
  bool _isOverviewUpdating = false;
  Timer? _overviewRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startRealtimeOverviewUpdates();
  }

  @override
  void dispose() {
    _overviewRefreshTimer?.cancel();
    super.dispose();
  }

  void _startRealtimeOverviewUpdates() {
    _overviewRefreshTimer?.cancel();
    _overviewRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshOverviewMetrics(),
    );
  }

  Future<void> _refreshOverviewMetrics() async {
    if (_isOverviewUpdating) return;

    setState(() => _isOverviewUpdating = true);
    try {
      final responses = await Future.wait([
        _apiService.getMetrics(),
        _apiService.getScans(),
      ]);
      final metrics = responses[0] as Map<String, dynamic>;
      final scans = responses[1] as List<Scan>;
      final weekScans = _countWeekScans(scans);

      if (!mounted) return;
      setState(() {
        _recentScans = scans.take(5).toList();
        _metrics = _normalizeOverviewMetrics(
          metrics,
          current: _metrics,
          weekScansOverride: weekScans,
        );
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (!mounted) return;
      setState(() => _isOverviewUpdating = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final scans = await _apiService.getScans();
      final metrics = await _apiService.getMetrics();
      final weekScans = _countWeekScans(scans);

      if (!mounted) return;

      setState(() {
        _recentScans = scans.take(5).toList();
        _metrics = _normalizeOverviewMetrics(
          metrics,
          current: _metrics,
          weekScansOverride: weekScans,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _metrics ??= {
          'total_scans': 0,
          'total_verified': 0,
          'accuracy': 0.0,
          'week_scans': 0,
        };
      });
    }
  }

  Map<String, dynamic> _normalizeOverviewMetrics(
    Map<String, dynamic> raw, {
    Map<String, dynamic>? current,
    int? weekScansOverride,
  }) {
    int toInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    double toDouble(dynamic value, {double fallback = 0.0}) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    final totalScans = toInt(
      raw['total_scans'] ?? raw['total_samples'],
      fallback: toInt(current?['total_scans'], fallback: 0),
    );

    final totalVerified = toInt(
      raw['total_verified'] ?? raw['samples_with_predictions'],
      fallback: toInt(current?['total_verified'], fallback: 0),
    );

    final accuracy = toDouble(
      raw['accuracy'] ?? raw['overall_metrics']?['accuracy'],
      fallback: toDouble(current?['accuracy'], fallback: 0.0),
    );

    final weekScans = toInt(
      raw['week_scans'],
      fallback: toInt(current?['week_scans'], fallback: totalScans),
    );

    return {
      ...?current,
      ...raw,
      'total_scans': totalScans,
      'total_verified': totalVerified,
      'accuracy': accuracy,
      'week_scans': weekScansOverride ?? weekScans,
    };
  }

  int _countWeekScans(List<Scan> scans) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return scans.where((scan) => scan.timestamp.isAfter(cutoff)).length;
  }

  List<({String label, double value, Color color})> _getMineralDistribution() {
    final perClass = _metrics?['per_class_metrics'];
    final map = perClass is Map ? perClass : <String, dynamic>{};

    double supportFor(String key) {
      final value = (map[key] as Map?)?['support'];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return [
      (
        label: 'Gold',
        value: supportFor('gold'),
        color: const Color(0xFFFFD700)
      ),
      (
        label: 'Chalco',
        value: supportFor('chalcopyrite'),
        color: const Color(0xFFB8860B)
      ),
      (
        label: 'Hematite',
        value: supportFor('hematite'),
        color: const Color(0xFF8B4513)
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: HomeHeaderWidget(
                  userName: _storageService.getUserName() ?? 'User',
                  subtitle: _isLoading ? 'Loading...' : 'Continue verifying minerals',
                  onNotificationTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                  onSettingsTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacingMd)),

              // Stats Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          height: 200,
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppTheme.spacingMd,
                            crossAxisSpacing: AppTheme.spacingMd,
                            childAspectRatio: 1.6,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            StatCard(
                              label: 'Total Scans',
                              value: '${_metrics?['total_scans'] ?? 0}',
                              icon: Icons.qr_code_scanner,
                              accentColor: AppTheme.primaryColor,
                              subtitle: 'This session',
                            ),
                            StatCard(
                              label: 'Verified',
                              value: '${_metrics?['total_verified'] ?? 0}',
                              icon: Icons.check_circle_outline,
                              accentColor: AppTheme.successColor,
                              highlighted: true,
                            ),
                            StatCard(
                              label: 'Accuracy',
                              value: '${((_metrics?['accuracy'] ?? 0.0) * 100).toStringAsFixed(0)}%',
                              icon: Icons.trending_up,
                              accentColor: AppTheme.infoColor,
                            ),
                            StatCard(
                              label: 'This Week',
                              value: '${_metrics?['week_scans'] ?? 0}',
                              icon: Icons.calendar_month,
                              accentColor: AppTheme.accentColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacingLg),
              ),

              // Featured Minerals Section
              if (_recentScans.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingLg,
                        ),
                        child: SectionHeaderWidget(
                          title: 'Recent Scans',
                          subtitle: 'Your latest mineral identifications',
                          actionLabel: 'View All',
                          onActionTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      SizedBox(
                        height: 280,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingLg,
                          ),
                          itemCount: math.min(3, _recentScans.length),
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: AppTheme.spacingMd),
                          itemBuilder: (context, index) {
                            final scan = _recentScans[index];
                            return SizedBox(
                              width: 240,
                              child: MineralCard(
                                name: scan.mineral,
                                image: '',
                                confidence:
                                    scan.confidencePercent.replaceAll('%', ''),
                                location: scan.location.isEmpty ? 'Unknown location' : scan.location,
                                status: scan.verified ? 'Verified' : 'Pending',
                                onTap: () {},
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacingLg),
              ),

              // Distribution Chart
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeaderWidget(
                        title: 'Mineral Distribution',
                        subtitle: 'Analysis from all verified scans',
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingLg),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          ),
                          boxShadow: AppTheme.softCardShadow,
                        ),
                        child: SizedBox(
                          height: 220,
                          child: _buildChart(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacingLg),
              ),

              // Map Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeaderWidget(
                        title: 'Exploration Map',
                        subtitle: 'Mineral mining sites in Rwanda',
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      MapEmbedWidget(
                        height: 400,
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacingXxl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    final distribution = _getMineralDistribution();
    final maxValue = distribution
        .map((item) => item.value)
        .fold<double>(0.0, (prev, value) => math.max(prev, value));
    final chartMaxY = maxValue <= 0 ? 1.0 : maxValue + 2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMaxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < distribution.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      distribution[value.toInt()].label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: [
          for (var i = 0; i < distribution.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: distribution[i].value,
                  color: distribution[i].color,
                  width: 40,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
