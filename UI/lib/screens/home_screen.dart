import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/user.dart';
import '../widgets/api_form_widget.dart';

import 'scan_mineral_screen.dart';
import 'verification_history_screen.dart';
import 'audit_trail_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  List<Widget> _getScreens() {
    return [
      const ScanMineralScreen(),
      const VerificationHistoryScreen(),
      const ApiFormWidget(),
      if (widget.user.role == UserRole.regulator) const AuditTrailScreen(),
    ];
  }

  List<BottomNavigationBarItem> _getNavItems() {
    final items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.camera_alt),
        label: 'Scan',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'History',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.cloud_upload_outlined),
        label: 'API',
      ),
    ];

    if (widget.user.role == UserRole.regulator) {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'Audit',
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final screens = _getScreens();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mineral Traceability'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                label: Text(
                  widget.user.role == UserRole.inspector
                      ? 'Inspector'
                      : 'Regulator',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: _getNavItems(),
      ),
    );
  }
}
