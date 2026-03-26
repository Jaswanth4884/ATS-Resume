import 'dart:async';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1;
  bool _isLoading = false;
  int _resendCooldownSeconds = 0;
  Timer? _resendTimer;
  String? _resetToken;

  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() {
      _resendCooldownSeconds = 30;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _resendCooldownSeconds = 0;
        });
        return;
      }

      setState(() {
        _resendCooldownSeconds -= 1;
      });
    });
  }

  Future<void> _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.sendPasswordResetOtp(
      email: _emailController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    final error = result['error'];
    final mockOtp = result['mockOtp'];
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    setState(() {
      _step = 2;
    });
    _startResendCooldown();
    _showMessage(
      mockOtp != null
          ? 'Demo OTP: $mockOtp'
          : 'OTP sent to your registered email.',
      isError: false,
    );
  }

  Future<void> _resendOtp() async {
    if (_resendCooldownSeconds > 0) {
      return;
    }

    final result = await AuthService.sendPasswordResetOtp(
      email: _emailController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    final error = result['error'];
    final mockOtp = result['mockOtp'];
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    _startResendCooldown();
    _showMessage(
      mockOtp != null
          ? 'Demo OTP: $mockOtp'
          : 'OTP sent again to your registered email.',
      isError: false,
    );
  }

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.verifyPasswordResetOtp(
      email: _emailController.text.trim(),
      otp: _otpController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    final error = result['error'];
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    setState(() {
      _resetToken = result['token'];
      _step = 3;
    });

    _showMessage('OTP verified. Set your new password.', isError: false);
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    final token = _resetToken;
    if (token == null || token.isEmpty) {
      _showMessage('Reset session expired. Verify OTP again.', isError: true);
      setState(() {
        _step = 2;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.changePasswordAfterReset(
      email: _emailController.text.trim(),
      resetToken: token,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    final error = result['error'];
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    _showMessage(
      'Password changed successfully. Confirmation mail has been sent.',
      isError: false,
    );
    Navigator.of(context).pop();
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF6B8E7F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: const Color(0xFF6B8E7F),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Reset your password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _step == 1
                        ? 'Enter your registered email to receive OTP'
                        : _step == 2
                        ? 'Enter OTP sent to your email'
                        : 'Create a new password',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_step == 1) _buildEmailStep(),
                  if (_step == 2) _buildOtpStep(),
                  if (_step == 3) _buildPasswordStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Registered email',
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6B8E7F)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6B8E7F), width: 2),
              ),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Send OTP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'Enter 6-digit OTP',
              prefixIcon: const Icon(Icons.password_outlined, color: Color(0xFF6B8E7F)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6B8E7F), width: 2),
              ),
            ),
            validator: (value) {
              final otp = value?.trim() ?? '';
              if (otp.isEmpty) {
                return 'Please enter OTP';
              }
              if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                return 'Enter valid 6-digit OTP';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _resendCooldownSeconds > 0 ? null : _resendOtp,
            child: _resendCooldownSeconds > 0
                ? Text('Resend OTP in ${_resendCooldownSeconds}s')
                : const Text('Resend OTP'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Verify OTP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _newPasswordController,
            obscureText: !_isNewPasswordVisible,
            decoration: InputDecoration(
              hintText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6B8E7F)),
              suffixIcon: IconButton(
                icon: Icon(
                  _isNewPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isNewPasswordVisible = !_isNewPasswordVisible;
                  });
                },
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6B8E7F), width: 2),
              ),
            ),
            validator: (value) {
              final password = value ?? '';
              if (password.isEmpty) {
                return 'Please enter new password';
              }
              if (password.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (!password.contains(RegExp(r'[A-Z]'))) {
                return 'Password must include one uppercase letter';
              }
              if (!password.contains(RegExp(r'[0-9]'))) {
                return 'Password must include one number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            decoration: InputDecoration(
              hintText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6B8E7F)),
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6B8E7F), width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Change Password'),
            ),
          ),
        ],
      ),
    );
  }
}
