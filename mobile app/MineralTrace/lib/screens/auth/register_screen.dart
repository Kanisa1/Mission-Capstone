import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _organizationController = TextEditingController();
  final _apiService = ApiService();
  final _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: AppConstants.googleServerClientId.isEmpty
        ? null
        : AppConstants.googleServerClientId,
  );

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'operator';

  bool get _isGoogleSignInSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        organization: _organizationController.text.trim().isNotEmpty
            ? _organizationController.text.trim()
            : null,
      );

      if (mounted) {
        // Show success message
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              color: AppTheme.successColor,
              size: 64,
            ),
            title: const Text('Registration Successful!'),
            content: const Text(
              'Your account has been created and is pending admin approval. '
              'You will be notified once your account is approved.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to login
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!_isGoogleSignInSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google Sign-In is not supported on Windows desktop. Run on Android, iOS, or Web.',
            ),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled sign-in
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if ((idToken == null || idToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        throw Exception(
          'Google token not available. Add android/app/google-services.json and set GOOGLE_SERVER_CLIENT_ID.',
        );
      }

      // Send Google token to backend for registration/login
      final response = await _apiService.googleSignIn(
        idToken: idToken,
        accessToken: accessToken,
        name: googleUser.displayName ?? '',
        email: googleUser.email,
        photoUrl: googleUser.photoUrl,
      );

      if (mounted) {
        // Check if there's a message (indicates new user registration)
        if (response.containsKey('message')) {
          // New user - show pending approval message
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              icon: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.successColor,
                size: 64,
              ),
              title: const Text('Registration Successful!'),
              content: Text(
                response['message'] ??
                    'Your Google account has been registered and is pending admin approval.',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to login
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          );
        } else {
          // Existing user - show message and go to login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Account already exists. Please use the login screen.'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
          // Navigate back to login after delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final isConfigIssue = (e.message ?? '').contains('10') ||
          (e.message ?? '').contains('DEVELOPER_ERROR');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConfigIssue
                ? 'Google Sign-In setup incomplete. Add google-services.json and OAuth SHA-1 in Firebase.'
                : 'Google Sign-In failed: ${e.message ?? e.code}',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.diamond_outlined,
                              size: 50,
                              color: AppTheme.primaryColor,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign up to get started',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),

                // Google Sign-In Button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: Image.asset(
                    'assets/images/goggle.png',
                    height: 24,
                    width: 24,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.login, size: 24),
                  ),
                  label: const Text('Sign up with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.grey),
                    foregroundColor: Colors.black,
                  ),
                ),

                const SizedBox(height: 24),

                // Divider
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 24),

                // Full Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Role Selection
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'operator', child: Text('Operator')),
                    DropdownMenuItem(
                        value: 'verifier', child: Text('Verifier')),
                    DropdownMenuItem(value: 'auditor', child: Text('Auditor')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedRole = value!);
                  },
                ),
                const SizedBox(height: 16),

                // Organization Field (Optional)
                TextFormField(
                  controller: _organizationController,
                  decoration: const InputDecoration(
                    labelText: 'Organization (Optional)',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: () {
                        // Safe pop: check if we can pop before popping
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          // Fallback: navigate to login if no history
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Note about approval
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All new accounts require admin approval before you can log in.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
