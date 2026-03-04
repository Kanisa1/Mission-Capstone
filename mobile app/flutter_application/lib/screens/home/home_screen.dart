import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/scan.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
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
  DateTime? _metricsLastUpdated;
  Timer? _overviewRefreshTimer;

  List<BoxShadow> get _softShadow => [
        BoxShadow(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

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
        _metricsLastUpdated = DateTime.now();
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
        _metricsLastUpdated = DateTime.now();
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
        _metricsLastUpdated = DateTime.now();
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
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.04),
                AppTheme.backgroundColor,
              ],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primaryColor,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeroHeader(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
                SliverToBoxAdapter(
                  child: _buildFeaturedCard(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overview',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        Row(
                          children: [
                            if (_isOverviewUpdating)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            else
                              const Icon(
                                Icons.circle,
                                size: 10,
                                color: AppTheme.successColor,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              _metricsLastUpdated == null
                                  ? 'Live'
                                  : 'Updated ${DateFormat('HH:mm:ss').format(_metricsLastUpdated!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Scans',
                            '${_metrics?['total_scans'] ?? 0}',
                            Icons.qr_code_scanner,
                            AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Verified',
                            '${_metrics?['total_verified'] ?? 0}',
                            Icons.verified_outlined,
                            AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Accuracy',
                            '${((_metrics?['accuracy'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                            Icons.analytics_outlined,
                            AppTheme.infoColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'This Week',
                            '${_metrics?['week_scans'] ?? 0}',
                            Icons.calendar_today_outlined,
                            AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      ),
                      boxShadow: _softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mineral Distribution',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '${_metrics?['total_scans'] ?? 0} samples',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Live class distribution from verified records',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(height: 200, child: _buildChart()),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Scans',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('See All'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _buildRecentScansTable(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.secondaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: _softShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            right: -20,
            top: -16,
            child: Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -22,
            bottom: -48,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.diamond_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'MineralTrace',
                        style: TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildNavIcon(
                        Icons.notifications_outlined,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildNavIcon(
                        Icons.person_outline,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildNavIcon(
                        Icons.settings_outlined,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Field Intelligence Dashboard',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Professional mineral verification with fast, AI-powered analysis',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.90),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroTag(icon: Icons.verified, label: 'Trusted Results'),
                  _HeroTag(icon: Icons.bolt, label: 'Fast Workflow'),
                  _HeroTag(icon: Icons.insights, label: 'Data Driven'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildFeaturedCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 780;

    final featureWidth = isNarrow ? double.infinity : screenWidth * 0.30;
    final imageHeight = isNarrow ? 230.0 : 270.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.08)),
        boxShadow: _softShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -12,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 2, 6, 10),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 16, color: AppTheme.primaryColor),
                    SizedBox(width: 6),
                    Text(
                      'Mineral Intelligence Showcase',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFeaturedImage(featureWidth, imageHeight),
                        const SizedBox(height: 12),
                        _buildAppExplanationCard(),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFeaturedImage(featureWidth, imageHeight),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: featureWidth,
                          child: _buildAppExplanationCard(height: imageHeight),
                        ),
                      ],
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: _softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/image.png', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.14),
                  Colors.black.withValues(alpha: 0.58),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Live AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Text(
              'Smart mineral recognition in the field',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppExplanationCard({double? height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.primaryColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.08)),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'About MineralTrace',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: 46,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'MineralTrace helps field teams scan and verify minerals with multimodal AI analysis.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureItem('Capture mineral images quickly'),
          const SizedBox(height: 8),
          _buildFeatureItem('Analyze confidence and verification status'),
          const SizedBox(height: 8),
          _buildFeatureItem('Track results with recent scan history'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle,
            size: 16,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.06)),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 26,
              height: 4,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
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
                  width: 36,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecentScansTable() {
    if (_recentScans.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.05)),
          boxShadow: _softShadow,
        ),
        child: const Center(
          child: Text(
            'No scans yet',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.05)),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Mineral',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Confidence',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final scan in _recentScans) _buildScanRow(scan),
        ],
      ),
    );
  }

  Widget _buildScanRow(Scan scan) {
    final isVerified = scan.verified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.mineral,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd • HH:mm').format(scan.timestamp),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              scan.confidencePercent,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isVerified
                          ? AppTheme.successColor
                          : AppTheme.warningColor)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isVerified ? 'Verified' : 'Pending',
                  style: TextStyle(
                    color: isVerified
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanItem(Scan scan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.05)),
        boxShadow: _softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color(
                AppConstants.mineralColors[scan.mineral.toLowerCase()] ??
                    0xFFCCCCCC,
              ).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.diamond, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.mineral,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • HH:mm').format(scan.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  scan.confidencePercent,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                scan.verified ? 'Verified' : 'Pending',
                style: TextStyle(
                  fontSize: 11,
                  color: scan.verified
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
