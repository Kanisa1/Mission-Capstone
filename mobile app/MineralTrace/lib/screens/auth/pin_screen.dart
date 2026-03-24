import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../config/theme.dart';
import '../../services/storage_service.dart';
import '../main/main_screen.dart';

class PinScreen extends StatefulWidget {
  final bool isSetup;
  final bool isVerification;

  const PinScreen({
    super.key,
    this.isSetup = false,
    this.isVerification = false,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pinController = TextEditingController();
  final _storageService = StorageService();
  String? _setupPin;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _handlePinComplete(String pin) async {
    if (widget.isSetup && _setupPin == null) {
      // First PIN entry during setup
      setState(() => _setupPin = pin);
      _pinController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm your PIN'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (widget.isSetup && _setupPin != null) {
      // Confirm PIN during setup
      if (pin == _setupPin) {
        await _storageService.setString('user_pin', pin);
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainScreen(),
            ),
          );
        }
      } else {
        _pinController.clear();
        setState(() => _setupPin = null);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PINs do not match. Try again'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } else if (widget.isVerification) {
      // Verify existing PIN
      final savedPin = _storageService.getString('user_pin');
      
      if (pin == savedPin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
          ),
        );
      } else {
        _pinController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect PIN'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
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
        leading: widget.isSetup
            ? null  // No back button during PIN setup
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Title
              Text(
                widget.isSetup
                    ? (_setupPin == null ? 'Create Your PIN' : 'Confirm Your PIN')
                    : 'Enter PIN Code',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              Text(
                widget.isSetup
                    ? (_setupPin == null
                        ? 'Set a 4-digit PIN for secure access'
                        : 'Re-enter your PIN to confirm')
                    : 'Enter your 4-digit PIN to continue',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              // PIN input
              Pinput(
                controller: _pinController,
                length: 4,
                obscureText: true,
                defaultPinTheme: PinTheme(
                  width: 64,
                  height: 64,
                  textStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.textLight,
                    ),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 64,
                  height: 64,
                  textStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                submittedPinTheme: PinTheme(
                  width: 64,
                  height: 64,
                  textStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                onCompleted: _handlePinComplete,
                autofocus: true,
              ),
              
              const Spacer(),
              
              // Forgot PIN (only for verification)
              if (widget.isVerification)
                TextButton(
                  onPressed: () {
                    // TODO: Implement forgot PIN
                  },
                  child: const Text('Forgot PIN?'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
