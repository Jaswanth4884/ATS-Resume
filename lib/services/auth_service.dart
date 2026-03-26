import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class AuthService {
  // ========== CONFIGURATION ==========
  // Set to true to use mock authentication (for testing without backend)
  // Set to false and update _baseUrl to use real backend
  static const bool USE_MOCK_AUTH = true;
  
  // Replace with your actual backend API URL
  static const String _baseUrl = 'https://api.example.com';

  static const String _mockUsersStorageKey = 'auth_mock_users_v1';
  static const String _mockPendingOtpStorageKey = 'auth_mock_pending_otp_v1';
  static const String _mockPasswordResetOtpStorageKey =
      'auth_mock_password_reset_otp_v1';
  
  // Mock users for development (remove in production)
  static final Map<String, Map<String, String>> _mockUsers = {
    'user@example.com': {
      'password': 'Password123',
      'name': 'Test User',
      'isVerified': 'true',
    },
    'demo@test.com': {
      'password': 'Demo@123',
      'name': 'Demo User',
      'isVerified': 'true',
    },
  };
  static bool _mockUsersLoaded = false;
  static final Map<String, String> _pendingMockOtps = {};
  static bool _mockOtpsLoaded = false;
  static final Map<String, String> _pendingPasswordResetOtps = {};
  static bool _passwordResetOtpsLoaded = false;
  static final Map<String, String> _passwordResetTokens = {};

  // Store token in memory (in production, use secure_storage)
  static String? _authToken;
  static DateTime? _tokenExpiry;
  static String? _currentUserIdentifier;

  /// Login with email and password
  static Future<Map<String, String?>> login({
    required String email,
    required String password,
  }) async {
    try {
      // Clear any existing token
      _authToken = null;
      _tokenExpiry = null;
      _currentUserIdentifier = null;

      // Use mock authentication for development
      if (USE_MOCK_AUTH) {
        return _mockLogin(email, password);
      }

      // Real backend authentication
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        final expiresIn = data['expiresIn'] as int? ?? 3600;

        if (token == null || token.isEmpty) {
          return {'token': null, 'error': 'Invalid response: missing token'};
        }

        // Store token and expiry
        _authToken = token;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        _currentUserIdentifier = email.trim().toLowerCase();

        return {'token': token, 'error': null};
      } else if (response.statusCode == 401) {
        return {'token': null, 'error': 'Invalid email or password'};
      } else if (response.statusCode == 404) {
        return {'token': null, 'error': 'User not found. Please sign up first.'};
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final message = errorData['message'] as String? ?? 'Login failed';
        return {'token': null, 'error': message};
      }
    } on FormatException {
      return {'token': null, 'error': 'Invalid response format from server'};
    } catch (e) {
      return {'token': null, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Mock login for development/testing
  static Future<Map<String, String?>> _mockLogin(
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _ensureMockUsersLoaded();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final user = _mockUsers[normalizedEmail];
    if (user == null) {
      return {'token': null, 'error': 'User not found. Please sign up first.'};
    }

    if (user['password'] != password) {
      return {'token': null, 'error': 'Invalid email or password'};
    }

    final isVerified = (user['isVerified'] ?? 'true').toLowerCase() == 'true';
    if (!isVerified) {
      return {
        'token': null,
        'error': 'Please verify OTP sent to your email before login.'
      };
    }

    // Generate mock token
    final token =
      'mock_token_${DateTime.now().millisecondsSinceEpoch}_${normalizedEmail.hashCode}';
    _authToken = token;
    _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
    _currentUserIdentifier = normalizedEmail;

    return {'token': token, 'error': null};
  }

  /// Sign up new user
  static Future<Map<String, String?>> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Clear any existing token
      _authToken = null;
      _tokenExpiry = null;
      _currentUserIdentifier = null;

      // Use mock authentication for development
      if (USE_MOCK_AUTH) {
        return _mockSignup(name, email, password);
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String?;

        if (token == null || token.isEmpty) {
          return {'token': null, 'error': 'Invalid response: missing token'};
        }

        return {'token': token, 'error': null};
      } else if (response.statusCode == 409) {
        return {'token': null, 'error': 'Email already registered'};
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final message = errorData['message'] as String? ?? 'Signup failed';
        return {'token': null, 'error': message};
      }
    } catch (e) {
      return {'token': null, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Mock signup for development/testing
  static Future<Map<String, String?>> _mockSignup(
    String name,
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _ensureMockUsersLoaded();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Check if email already exists
    if (_mockUsers.containsKey(normalizedEmail)) {
      return {'token': null, 'error': 'Email already registered'};
    }

    // Validate password strength (at least 8 chars, one uppercase, one number)
    if (password.length < 8) {
      return {
        'token': null,
        'error': 'Password must be at least 8 characters long'
      };
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return {
        'token': null,
        'error': 'Password must contain at least one uppercase letter'
      };
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      return {
        'token': null,
        'error': 'Password must contain at least one number'
      };
    }

    // Add new user to mock database (unverified until OTP is validated)
    _mockUsers[normalizedEmail] = {
      'password': password,
      'name': name,
      'isVerified': 'false',
    };
    await _persistMockUsers();

    return {'token': 'registered', 'error': null};
  }

  static Future<void> _ensureMockUsersLoaded() async {
    if (_mockUsersLoaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mockUsersStorageKey);
    if (raw == null || raw.isEmpty) {
      _mockUsersLoaded = true;
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _mockUsers.addAll(
          decoded.map(
            (email, userData) {
              final normalizedEmail = email.trim().toLowerCase();
              if (userData is Map) {
                return MapEntry(
                  normalizedEmail,
                  userData.map(
                    (key, value) =>
                        MapEntry(key.toString(), value.toString()),
                  ),
                );
              }
              return MapEntry(normalizedEmail, <String, String>{});
            },
          ),
        );
      }
    } catch (_) {
      // Keep default users when stored data is invalid.
    } finally {
      _mockUsersLoaded = true;
    }
  }

  static Future<void> _ensureMockOtpsLoaded() async {
    if (_mockOtpsLoaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mockPendingOtpStorageKey);
    if (raw == null || raw.isEmpty) {
      _mockOtpsLoaded = true;
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _pendingMockOtps
          ..clear()
          ..addAll(
            decoded.map(
              (email, otp) =>
                  MapEntry(email.trim().toLowerCase(), otp.toString()),
            ),
          );
      }
    } catch (_) {
      // Ignore invalid stored OTP data.
    } finally {
      _mockOtpsLoaded = true;
    }
  }

  static Future<void> _persistMockOtps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mockPendingOtpStorageKey, jsonEncode(_pendingMockOtps));
  }

  static Future<void> _ensurePasswordResetOtpsLoaded() async {
    if (_passwordResetOtpsLoaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mockPasswordResetOtpStorageKey);
    if (raw == null || raw.isEmpty) {
      _passwordResetOtpsLoaded = true;
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _pendingPasswordResetOtps
          ..clear()
          ..addAll(
            decoded.map(
              (email, otp) =>
                  MapEntry(email.trim().toLowerCase(), otp.toString()),
            ),
          );
      }
    } catch (_) {
      // Ignore invalid stored OTP data.
    } finally {
      _passwordResetOtpsLoaded = true;
    }
  }

  static Future<void> _persistPasswordResetOtps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _mockPasswordResetOtpStorageKey,
      jsonEncode(_pendingPasswordResetOtps),
    );
  }

  static String _generateOtpCode() {
    final code = (DateTime.now().millisecondsSinceEpoch % 900000) + 100000;
    return code.toString();
  }

  static Future<Map<String, String?>> sendRegistrationOtp({
    required String email,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      if (USE_MOCK_AUTH) {
        await _ensureMockUsersLoaded();
        await _ensureMockOtpsLoaded();

        if (!_mockUsers.containsKey(normalizedEmail)) {
          return {'success': null, 'error': 'User not found. Please sign up first.'};
        }

        final otp = _generateOtpCode();
        _pendingMockOtps[normalizedEmail] = otp;
        await _persistMockOtps();
        debugPrint('Mock OTP for $normalizedEmail: $otp');

        return {'success': 'true', 'error': null, 'mockOtp': otp};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/send-registration-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': normalizedEmail}),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        return {'success': 'true', 'error': null};
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final message = errorData['message'] as String? ?? 'Failed to send OTP';
      return {'success': null, 'error': message};
    } catch (e) {
      return {'success': null, 'error': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, String?>> verifyRegistrationOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      if (USE_MOCK_AUTH) {
        await _ensureMockUsersLoaded();
        await _ensureMockOtpsLoaded();

        final user = _mockUsers[normalizedEmail];
        if (user == null) {
          return {'success': null, 'error': 'User not found'};
        }

        final expectedOtp = _pendingMockOtps[normalizedEmail];
        if (expectedOtp == null) {
          return {'success': null, 'error': 'OTP expired. Please resend OTP.'};
        }

        if (expectedOtp != otp.trim()) {
          return {'success': null, 'error': 'Invalid OTP'};
        }

        user['isVerified'] = 'true';
        _pendingMockOtps.remove(normalizedEmail);
        await _persistMockUsers();
        await _persistMockOtps();

        return {'success': 'true', 'error': null};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-registration-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': normalizedEmail, 'otp': otp.trim()}),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        return {'success': 'true', 'error': null};
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final message = errorData['message'] as String? ?? 'OTP verification failed';
      return {'success': null, 'error': message};
    } catch (e) {
      return {'success': null, 'error': 'Network error: ${e.toString()}'};
    }
  }

  static Future<void> _persistMockUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mockUsersStorageKey, jsonEncode(_mockUsers));
  }

  /// Validate session token
  static Future<bool> validateSession() async {
    try {
      if (_authToken == null || _tokenExpiry == null) {
        return false;
      }

      // Check if token has expired
      if (DateTime.now().isAfter(_tokenExpiry!)) {
        _authToken = null;
        _tokenExpiry = null;
        return false;
      }

      // Use mock validation for development
      if (USE_MOCK_AUTH) {
        return _mockValidateSession();
      }

      // Verify token with backend
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/verify'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        _authToken = null;
        _tokenExpiry = null;
        return false;
      }
    } catch (e) {
      _authToken = null;
      _tokenExpiry = null;
      return false;
    }
  }

  /// Mock session validation for development/testing
  static bool _mockValidateSession() {
    // For mock auth, just check if token exists and hasn't expired
    if (_authToken == null || _tokenExpiry == null) {
      return false;
    }

    if (DateTime.now().isAfter(_tokenExpiry!)) {
      _authToken = null;
      _tokenExpiry = null;
      return false;
    }

    return true;
  }

  /// Get current auth token
  static String? getToken() {
    if (_authToken == null || _tokenExpiry == null) {
      return null;
    }

    // Check if token has expired
    if (DateTime.now().isAfter(_tokenExpiry!)) {
      _authToken = null;
      _tokenExpiry = null;
      return null;
    }

    return _authToken;
  }

  /// Check if user is authenticated
  static bool isAuthenticated() {
    return _authToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!);
  }

  static String? get currentUserIdentifier => _currentUserIdentifier;

  /// Logout and clear session
  static Future<void> logout() async {
    try {
      if (_authToken != null) {
        // Notify backend of logout
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {
            'Authorization': 'Bearer $_authToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      // Continue logout even if backend call fails
    } finally {
      // Clear all stored data
      _authToken = null;
      _tokenExpiry = null;
      _currentUserIdentifier = null;
    }
  }

  /// Refresh authentication token
  static Future<Map<String, String?>> refreshToken() async {
    try {
      if (_authToken == null) {
        return {'token': null, 'error': 'No token to refresh'};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        final expiresIn = data['expiresIn'] as int? ?? 3600;

        if (token == null) {
          return {'token': null, 'error': 'Invalid response: missing token'};
        }

        _authToken = token;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        return {'token': token, 'error': null};
      } else {
        _authToken = null;
        _tokenExpiry = null;
        _currentUserIdentifier = null;
        return {'token': null, 'error': 'Token refresh failed'};
      }
    } catch (e) {
      _authToken = null;
      _tokenExpiry = null;
      _currentUserIdentifier = null;
      return {'token': null, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Make authenticated API request
  static Future<http.Response> getAuthenticatedRequest(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final token = getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final mergedHeaders = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?headers,
    };

    return http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: mergedHeaders,
    );
  }

  /// Reset user password
  static Future<Map<String, dynamic>> requestPasswordReset(
    String email,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/password-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'error': null};
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final message = errorData['message'] as String? ?? 'Request failed';
        return {'success': false, 'error': message};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, String?>> sendPasswordResetOtp({
    required String email,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      if (USE_MOCK_AUTH) {
        await _ensureMockUsersLoaded();
        await _ensurePasswordResetOtpsLoaded();

        if (!_mockUsers.containsKey(normalizedEmail)) {
          _mockUsers[normalizedEmail] = {
            'password': 'Temp@1234',
            'name': 'Recovered User',
            'isVerified': 'true',
          };
          await _persistMockUsers();
          debugPrint(
            'Recovered missing mock account record for $normalizedEmail during password reset.',
          );
        }

        final otp = _generateOtpCode();
        _pendingPasswordResetOtps[normalizedEmail] = otp;
        _passwordResetTokens.remove(normalizedEmail);
        await _persistPasswordResetOtps();
        debugPrint('Mock password reset OTP for $normalizedEmail: $otp');

        return {'success': 'true', 'error': null, 'mockOtp': otp};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/password-reset/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': normalizedEmail}),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        return {'success': 'true', 'error': null};
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final message =
          errorData['message'] as String? ?? 'Failed to send password reset OTP';
      return {'success': null, 'error': message};
    } catch (e) {
      return {'success': null, 'error': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, String?>> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final trimmedOtp = otp.trim();

      if (USE_MOCK_AUTH) {
        await _ensureMockUsersLoaded();
        await _ensurePasswordResetOtpsLoaded();

        if (!_mockUsers.containsKey(normalizedEmail)) {
          return {'success': null, 'token': null, 'error': 'User not found'};
        }

        final expectedOtp = _pendingPasswordResetOtps[normalizedEmail];
        if (expectedOtp == null) {
          return {'success': null, 'token': null, 'error': 'OTP expired. Please resend OTP.'};
        }

        if (expectedOtp != trimmedOtp) {
          return {'success': null, 'token': null, 'error': 'Invalid OTP'};
        }

        final verificationToken =
            'reset_token_${DateTime.now().millisecondsSinceEpoch}_${normalizedEmail.hashCode}';
        _passwordResetTokens[normalizedEmail] = verificationToken;
        _pendingPasswordResetOtps.remove(normalizedEmail);
        await _persistPasswordResetOtps();

        return {'success': 'true', 'token': verificationToken, 'error': null};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/password-reset/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': normalizedEmail, 'otp': trimmedOtp}),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['resetToken'] as String?;
        return {'success': 'true', 'token': token, 'error': null};
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final message = errorData['message'] as String? ?? 'OTP verification failed';
      return {'success': null, 'token': null, 'error': message};
    } catch (e) {
      return {'success': null, 'token': null, 'error': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, String?>> changePasswordAfterReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      if (USE_MOCK_AUTH) {
        await _ensureMockUsersLoaded();

        final user = _mockUsers[normalizedEmail];
        if (user == null) {
          return {'success': null, 'error': 'User not found'};
        }

        final expectedToken = _passwordResetTokens[normalizedEmail];
        if (expectedToken == null || expectedToken != resetToken) {
          return {
            'success': null,
            'error': 'Password reset session expired. Verify OTP again.'
          };
        }

        if (newPassword.length < 8) {
          return {
            'success': null,
            'error': 'Password must be at least 8 characters long'
          };
        }
        if (!newPassword.contains(RegExp(r'[A-Z]'))) {
          return {
            'success': null,
            'error': 'Password must contain at least one uppercase letter'
          };
        }
        if (!newPassword.contains(RegExp(r'[0-9]'))) {
          return {
            'success': null,
            'error': 'Password must contain at least one number'
          };
        }

        user['password'] = newPassword;
        _passwordResetTokens.remove(normalizedEmail);
        await _persistMockUsers();

        debugPrint('Mock email notification: Password changed for $normalizedEmail');
        return {'success': 'true', 'error': null};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/password-reset/change'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': normalizedEmail,
          'resetToken': resetToken,
          'newPassword': newPassword,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        return {'success': 'true', 'error': null};
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final message =
          errorData['message'] as String? ?? 'Password change failed';
      return {'success': null, 'error': message};
    } catch (e) {
      return {'success': null, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
