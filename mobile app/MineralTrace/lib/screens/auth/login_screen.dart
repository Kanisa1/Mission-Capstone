import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import 'pin_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  final _storageService = StorageService();
  final _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: AppConstants.googleServerClientId.isEmpty
        ? null
        : AppConstants.googleServerClientId,
  );
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isGoogleSignInSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // First check approval status
      final approvalStatus = await _apiService.checkApprovalStatus(
        _emailController.text.trim(),
      );

      if (approvalStatus['approval_status'] == 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Your account is pending admin approval. Please wait for approval.'),
              backgroundColor: AppTheme.warningColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      } else if (approvalStatus['approval_status'] == 'denied') {
        if (mounted) {
          final reason =
              approvalStatus['denied_reason'] ?? 'No reason provided';
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.cancel_outlined,
                  color: AppTheme.errorColor, size: 64),
              title: const Text('Account Denied'),
              content: Text('Your account has been denied.\n\nReason: $reason'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // If approved, proceed with login
      final response = await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Save user data (API returns user object nested under 'user' key)
      final user = response['user'];
      await _storageService.saveUserData(
        userId: user['id'] ?? '',
        name: user['name'] ?? '',
        email: user['email'] ?? _emailController.text,
        role: user['role'] ?? 'operator',
      );

      if (mounted) {
        // Navigate to PIN screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PinScreen(isSetup: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
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

      // Send Google token to backend
      final response = await _apiService.googleSignIn(
        idToken: idToken,
        accessToken: accessToken,
        name: googleUser.displayName ?? '',
        email: googleUser.email,
        photoUrl: googleUser.photoUrl,
      );

      // Check if user has pending approval (new user)
      if (response.containsKey('message')) {
        // New user registration - show pending approval message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Account pending approval'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Check approval status from user object
      final user = response['user'];
      final approvalStatus = user['approval_status'] ?? 'approved';

      if (approvalStatus == 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account is pending admin approval.'),
              backgroundColor: AppTheme.warningColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      } else if (approvalStatus == 'denied') {
        if (mounted) {
          final reason = user['denied_reason'] ?? 'No reason provided';
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.cancel_outlined,
                  color: AppTheme.errorColor, size: 64),
              title: const Text('Account Denied'),
              content: Text('Your account has been denied.\n\nReason: $reason'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // If approved, save data and proceed
      await _storageService.saveUserData(
        userId: user['id'] ?? '',
        name: user['name'] ?? googleUser.displayName ?? '',
        email: user['email'] ?? googleUser.email,
        role: user['role'] ?? 'operator',
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PinScreen(isSetup: true),
          ),
        );
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
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.07),
                AppTheme.backgroundColor,
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08)),
                boxShadow: AppTheme.softCardShadow,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 18),

                    // Logo
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
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
                            padding: const EdgeInsets.all(20.0),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.diamond_outlined,
                                  size: 60,
                                  color: AppTheme.primaryColor,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Sign in to continue mineral tracing',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 34),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Login button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Divider
                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child:
                              Text('OR', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Google Sign-In button
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        icon: Image.asset(
                          'assets/images/goggle.png',
                          height: 24,
                          width: 24,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.login, size: 24),
                        ),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Forgot password
                    TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password
                      },
                      child: const Text('Forgot Password?'),
                    ),

                    const SizedBox(height: 10),

                    // TODO: Implement forgot password (could show reset flow)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
