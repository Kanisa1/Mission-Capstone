import 'package:flutter/material.dart';
import '../../widgets/curved_app_bar.dart';
import '../../widgets/chat_assistant_button.dart';
import '../home/home_screen.dart';
import '../scan/scan_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _switchToHome() {
    if (!mounted) return;
    setState(() => _currentIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final contextMap = {
      0: 'general',
      1: 'scanning',
      2: 'results',
      3: 'general',
    };

    return Scaffold(
      appBar: CurvedAppBar(
        title: 'MineralTrace',
        showBackButton: false,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          const HistoryScreen(),
          ScanScreen(onVerificationCompleted: _switchToHome),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: ChatAssistantButton(
        currentContext: contextMap[_currentIndex] ?? 'general',
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 70,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

