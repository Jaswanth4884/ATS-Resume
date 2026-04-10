import 'package:flutter/material.dart';
import 'dart:async';
import 'services/auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final bool _usesFirebaseEmailVerification =
      AuthService.usesFirebaseEmailVerification;
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldownSeconds = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
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

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!_usesFirebaseEmailVerification && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    final result = await AuthService.verifyRegistrationOtp(
      email: widget.email,
      otp: _usesFirebaseEmailVerification ? '000000' : _otpController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isVerifying = false;
    });

    final error = result['error'];
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    _showMessage(
      _usesFirebaseEmailVerification
          ? 'Email verified successfully from Firebase. Please login.'
          : 'Email verified successfully. Please login.',
      isError: false,
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _resendOtp() async {
    if (_resendCooldownSeconds > 0) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    final result = await AuthService.sendRegistrationOtp(email: widget.email);

    if (!mounted) {
      return;
    }

    setState(() {
      _isResending = false;
    });

    final error = result['error'];
    final warning = result['warning'];
    final mockOtp = result['mockOtp'];
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    _showMessage(mockOtp != null
        ? 'Demo OTP: $mockOtp'
        : (warning ?? 'OTP sent again to your email.'), isError: false);
    _startResendCooldown();
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
        backgroundColor: const Color(0xFF6B8E7F),
        foregroundColor: Colors.white,
        title: const Text('Email Verification'),
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 54,
                      color: Color(0xFF6B8E7F),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _usesFirebaseEmailVerification
                          ? 'A Firebase verification email has been sent to ${widget.email}'
                          : 'An OTP has been sent to ${widget.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_usesFirebaseEmailVerification)
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          hintText: 'Enter 6-digit OTP',
                          prefixIcon: const Icon(
                            Icons.password_outlined,
                            color: Color(0xFF6B8E7F),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF6B8E7F),
                              width: 2,
                            ),
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
                    if (_usesFirebaseEmailVerification)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Open your email and click the verification link, then tap Verify below.',
                          style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B8E7F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(_usesFirebaseEmailVerification
                                ? 'I Verified My Email'
                                : 'Verify OTP'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: (_isResending || _resendCooldownSeconds > 0)
                          ? null
                          : _resendOtp,
                      child: _isResending
                          ? const Text('Sending OTP...')
                          : (_resendCooldownSeconds > 0
                                ? Text('Resend OTP in ${_resendCooldownSeconds}s')
                                : const Text('Resend OTP')),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'OTP verification is required only during registration.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                      ),
                    ),
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
