import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/storage_service.dart';
import '../auth/login_screen.dart';
import '../admin/admin_approval_screen.dart';
import 'edit_profile_screen.dart';
import 'change_pin_screen.dart';
import 'notifications_screen.dart';
import 'my_scans_screen.dart';
import 'analytics_screen.dart';
import 'reports_screen.dart';
import 'help_support_screen.dart';
import 'terms_conditions_screen.dart';
import 'about_app_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storageService = StorageService();
  
  String _userName = '';
  String _userEmail = '';
  String _userRole = '';
  String? _profilePicturePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    setState(() {
      _userName = _storageService.getUserName() ?? 'User';
      _userEmail = _storageService.getUserEmail() ?? '';
      _userRole = _storageService.getUserRole() ?? 'operator';
      _profilePicturePath = _storageService.getProfilePicture();
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _storageService.clearUserData();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with gradient background
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          image: _profilePicturePath != null
                              ? DecorationImage(
                                  image: FileImage(File(_profilePicturePath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _profilePicturePath == null
                            ? Center(
                                child: Text(
                                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Name
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Email
                      Text(
                        _userEmail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _userRole.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Menu items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildMenuSection(
                      'Account',
                      [
                        _buildMenuItem(
                          'Edit Profile',
                          Icons.person_outline,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const EditProfileScreen(),
                              ),
                            ).then((_) {
                              // Reload user data when returning from edit screen
                              _loadUserData();
                            });
                          },
                        ),
                        _buildMenuItem(
                          'Change PIN',
                          Icons.lock_outline,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ChangePinScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          'Notifications',
                          Icons.notifications_outlined,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const NotificationsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Admin section (only for admin role)
                    if (_userRole.toLowerCase() == 'admin') ...[
                      _buildMenuSection(
                        'Admin',
                        [
                          _buildMenuItem(
                            'Pending Approvals',
                            Icons.how_to_reg_outlined,
                            () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AdminApprovalScreen(),
                                ),
                              );
                            },
                          ),
                          _buildMenuItem(
                            'User Management',
                            Icons.people_outline,
                            () {
                              // TODO: Navigate to user management
                            },
                          ),
                          _buildMenuItem(
                            'System Settings',
                            Icons.settings_outlined,
                            () {
                              // TODO: Navigate to system settings
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                    ],
                    
                    _buildMenuSection(
                      'Data & Analytics',
                      [
                        _buildMenuItem(
                          'My Scans',
                          Icons.qr_code_scanner_outlined,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const MyScansScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          'Analytics',
                          Icons.analytics_outlined,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const AnalyticsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          'Reports',
                          Icons.description_outlined,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ReportsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildMenuSection(
                      'About',
                      [
                        _buildMenuItem(
                          'Help & Support',
                          Icons.help_outline,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const HelpSupportScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          'Terms & Conditions',
                          Icons.description_outlined,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const TermsConditionsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          'About App',
                          Icons.info_outline,
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const AboutAppScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('LOGOUT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Version
                    Text(
                      'Version ${AppConstants.appVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textLight,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
