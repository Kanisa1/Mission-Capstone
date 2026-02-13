import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_theme.dart';
import 'screens/mobile/login_screen.dart';
import 'screens/mobile/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  
  runApp(MineralTraceabilityApp(showOnboarding: !hasSeenOnboarding));
}

class MineralTraceabilityApp extends StatelessWidget {
  final bool showOnboarding;
  
  const MineralTraceabilityApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mineral Traceability System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: showOnboarding ? const OnboardingScreen() : const LoginScreen(),
    );
  }
}
