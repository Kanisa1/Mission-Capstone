import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../models/user.dart';
import 'dashboard_overview_page.dart';
import 'verifications_page.dart';
import 'audit_trail_page.dart';
import 'mining_sites_minerals_page.dart';
import 'users_roles_page.dart';
import 'api_console_page.dart';

class WebMainScreen extends StatefulWidget {
  final User user;

  const WebMainScreen({super.key, required this.user});

  @override
  State<WebMainScreen> createState() => _WebMainScreenState();
}

class _WebMainScreenState extends State<WebMainScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem('Dashboard', Icons.dashboard_outlined),
    _NavItem('Verifications', Icons.verified_outlined),
    _NavItem('Audit Trail', Icons.assignment_outlined),
    _NavItem('Sites & Minerals', Icons.business_outlined),
    _NavItem('Users & Roles', Icons.people_outlined),
    _NavItem('API Console', Icons.cloud_upload_outlined),
  ];

  List<Widget> _getPages() {
    return [
      const DashboardOverviewPage(),
      const VerificationsPage(),
      const AuditTrailPage(),
      const MiningSitesMineralsPage(),
      const UsersRolesPage(),
      const ApiConsolePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width > 1200,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: AppColors.primary,
            selectedIconTheme: const IconThemeData(color: AppColors.accent),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedLabelTextStyle: const TextStyle(color: AppColors.accent),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Image.asset('assets/logo.png', height: 50),
                  const SizedBox(height: 8),
                  if (MediaQuery.of(context).size.width > 1200)
                    const Text(
                      'Mineral\nTraceability',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            destinations: _navItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
                label: Text(item.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _navItems[_selectedIndex].label,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          widget.user.role == UserRole.admin ? 'Admin' : 'Regulator',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: AppColors.accent,
                      ),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          widget.user.name[0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  _NavItem(this.label, this.icon);
}
