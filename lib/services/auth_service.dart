import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../firebase_options.dart';

class AuthService {
  // ========== CONFIGURATION ==========
  // Set true only when intentionally testing without backend.
  static const bool USE_MOCK_AUTH = bool.fromEnvironment(
    'USE_MOCK_AUTH',
    defaultValue: true,
  );

  static const bool USE_FIREBASE_EMAIL_VERIFICATION = bool.fromEnvironment(
    'USE_FIREBASE_EMAIL_VERIFICATION',
    defaultValue: true,
  );

  // Override at runtime using --dart-define=API_BASE_URL=...
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String _mockUsersStorageKey = 'auth_mock_users_v1';
  static const String _mockPendingOtpStorageKey = 'auth_mock_pending_otp_v1';
  static const String _mockPasswordResetOtpStorageKey =
      'auth_mock_password_reset_otp_v1';
  static const String _authSessionTokenStorageKey = 'auth_session_token_v1';
  static const String _authSessionExpiryStorageKey = 'auth_session_expiry_v1';
  static const String _authSessionUserStorageKey = 'auth_session_user_v1';
  static const String _authRememberMeStorageKey = 'auth_remember_me_v1';
  static const String _guestSessionPrefix = 'guest_session_';
  
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
  static bool _firebaseInitAttempted = false;
  static bool _firebaseReady = false;

  // Store token in memory (in production, use secure_storage)
  static String? _authToken;
  static DateTime? _tokenExpiry;
  static String? _currentUserIdentifier;
  static bool _rememberSession = true;

  static bool get usesFirebaseEmailVerification =>
      USE_MOCK_AUTH && USE_FIREBASE_EMAIL_VERIFICATION;

  static Future<bool> _ensureFirebaseReady() async {
    if (_firebaseInitAttempted) {
      return _firebaseReady;
    }

    _firebaseInitAttempted = true;
    try {
      if (Firebase.apps.isNotEmpty) {
        _firebaseReady = true;
        return true;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseReady = true;
      return true;
    } catch (e) {
      _firebaseReady = false;
      debugPrint(
        'Firebase not configured yet. Falling back to local mock auth flow.',
      );
      return false;
    }
  }

  static Future<void> _persistSession() async {
    final token = _authToken;
    final expiry = _tokenExpiry;
    if (token == null || expiry == null) {
      await _clearPersistedSession();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authRememberMeStorageKey, _rememberSession);
    await prefs.setString(_authSessionTokenStorageKey, token);
    await prefs.setInt(
      _authSessionExpiryStorageKey,
      expiry.millisecondsSinceEpoch,
    );

    final userId = _currentUserIdentifier;
    if (userId != null && userId.trim().isNotEmpty) {
      await prefs.setString(_authSessionUserStorageKey, userId.trim().toLowerCase());
    } else {
      await prefs.remove(_authSessionUserStorageKey);
    }
  }

  static Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authSessionTokenStorageKey);
    await prefs.remove(_authSessionExpiryStorageKey);
    await prefs.remove(_authSessionUserStorageKey);
    await prefs.remove(_authRememberMeStorageKey);
  }

  static Future<bool> _restoreSessionIfNeeded() async {
    if (_authToken != null && _tokenExpiry != null) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_authRememberMeStorageKey) ?? true;
    if (!rememberMe) {
      await _clearPersistedSession();
      return false;
    }

    final storedToken = prefs.getString(_authSessionTokenStorageKey);
    final storedExpiryMillis = prefs.getInt(_authSessionExpiryStorageKey);
    final storedUser = prefs.getString(_authSessionUserStorageKey);

    if (storedToken == null || storedToken.isEmpty || storedExpiryMillis == null) {
      return false;
    }

    final expiry = DateTime.fromMillisecondsSinceEpoch(storedExpiryMillis);
    if (DateTime.now().isAfter(expiry)) {
      await _clearPersistedSession();
      return false;
    }

    _authToken = storedToken;
    _tokenExpiry = expiry;
    _currentUserIdentifier =
        storedUser?.trim().toLowerCase();
    return true;
  }

  /// Login with email and password
  static Future<Map<String, String?>> login({
    required String email,
    required String password,
    bool rememberSession = true,
  }) async {
    try {
      // Clear any existing token
      _authToken = null;
      _tokenExpiry = null;
      _currentUserIdentifier = null;
      _rememberSession = rememberSession;

      // Use mock authentication for development
      if (USE_MOCK_AUTH) {
        return _mockLogin(email, password, rememberSession: rememberSession);
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
        if (_rememberSession) {
          await _persistSession();
        } else {
          await _clearPersistedSession();
        }

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
    {
    bool rememberSession = true,
  }
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    bool shouldFallbackToLocalMock = true;
    bool usedFirebaseLogin = false;
    String? firebaseAuthErrorCode;
    if (usesFirebaseEmailVerification && await _ensureFirebaseReady()) {
      usedFirebaseLogin = true;
      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: normalizedEmail, password: password);

        final firebaseUser = credential.user;
        if (firebaseUser == null) {
          return {'token': null, 'error': 'Login failed. Please try again.'};
        }

        await firebaseUser.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;
        if (refreshedUser == null || !refreshedUser.emailVerified) {
          await FirebaseAuth.instance.signOut();
          return {
            'token': null,
            'error': 'Please verify your email from OTP mail before login.',
          };
        }
        shouldFallbackToLocalMock = false;
      } on FirebaseAuthException catch (e) {
        firebaseAuthErrorCode = e.code;
        if (e.code == 'user-not-found') {
          shouldFallbackToLocalMock = true;
        } else if (e.code == 'invalid-credential') {
          // Some Firebase platforms return invalid-credential for unknown users.
          shouldFallbackToLocalMock = true;
        } else if (e.code == 'wrong-password') {
          return {'token': null, 'error': 'Invalid email or password'};
        } else {
          return {'token': null, 'error': e.message ?? 'Login failed'};
        }
      } catch (e) {
        return {'token': null, 'error': e.toString().replaceFirst('Exception: ', '')};
      }

      if (!shouldFallbackToLocalMock) {
        // Firebase auth succeeded and user is verified, issue local session token.
        final token =
            'mock_token_${DateTime.now().millisecondsSinceEpoch}_${normalizedEmail.hashCode}';
        _authToken = token;
        _tokenExpiry = DateTime.now().add(const Duration(days: 7));
        _currentUserIdentifier = normalizedEmail;
        _rememberSession = rememberSession;
        if (_rememberSession) {
          await _persistSession();
        } else {
          await _clearPersistedSession();
        }
        return {'token': token, 'error': null};
      }
    }

    await _ensureMockUsersLoaded();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final user = _mockUsers[normalizedEmail];
    if (user == null) {
      if (usedFirebaseLogin) {
        // In Firebase mode, avoid misleading fallback errors.
        if (firebaseAuthErrorCode == 'user-not-found') {
          return {'token': null, 'error': 'User not found. Please sign up first.'};
        }
        return {'token': null, 'error': 'Invalid email or password'};
      }
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
    _tokenExpiry = DateTime.now().add(const Duration(days: 7));
    _currentUserIdentifier = normalizedEmail;
    _rememberSession = rememberSession;
    if (_rememberSession) {
      await _persistSession();
    } else {
      await _clearPersistedSession();
    }

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

  static Future<Map<String, String?>> _storeMockSignupAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    await _ensureMockUsersLoaded();

    if (_mockUsers.containsKey(normalizedEmail)) {
      return {'token': null, 'error': 'Email already registered'};
    }

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

    _mockUsers[normalizedEmail] = {
      'password': password,
      'name': name,
      'isVerified': 'false',
    };
    await _persistMockUsers();

    return {
      'token': 'registered',
      'error': null,
      'delivery': 'mock',
    };
  }

  /// Mock signup for development/testing
  static Future<Map<String, String?>> _mockSignup(
    String name,
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (usesFirebaseEmailVerification && await _ensureFirebaseReady()) {
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: normalizedEmail, password: password);
        await credential.user?.updateDisplayName(name);
        await credential.user?.sendEmailVerification();

        // Keep mock storage in sync so login fallback never loses this account.
        await _ensureMockUsersLoaded();
        _mockUsers[normalizedEmail] = {
          'password': password,
          'name': name,
          'isVerified': 'false',
        };
        await _persistMockUsers();
        return {
          'token': 'registered',
          'error': null,
          'delivery': 'firebase',
        };
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          return {'token': null, 'error': 'Email already registered'};
        }
        if (e.code == 'weak-password') {
          return {'token': null, 'error': 'Password is too weak'};
        }
        if (e.code == 'too-many-requests' || e.code == 'quota-exceeded') {
          debugPrint(
            'Firebase signup blocked for $normalizedEmail, falling back to local mock signup.',
          );
          return _storeMockSignupAccount(
            name: name,
            email: email,
            password: password,
          );
        }
        return {'token': null, 'error': e.message ?? 'Signup failed'};
      } catch (e) {
        final message = e.toString().replaceFirst('Exception: ', '');
        if (message.contains('too-many-requests') ||
            message.contains('quota-exceeded')) {
          debugPrint(
            'Firebase signup blocked for $normalizedEmail, falling back to local mock signup.',
          );
          return _storeMockSignupAccount(
            name: name,
            email: email,
            password: password,
          );
        }
        return {'token': null, 'error': message};
      }
    }

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
    final normalizedEmail = email.trim().toLowerCase();
    try {
      if (USE_MOCK_AUTH) {
        if (usesFirebaseEmailVerification && await _ensureFirebaseReady()) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null ||
              currentUser.email?.trim().toLowerCase() != normalizedEmail) {
            return {
              'success': null,
              'error': 'Registration session expired. Please sign up again.',
            };
          }

          await currentUser.sendEmailVerification();
          return {
            'success': 'true',
            'error': null,
            'warning': 'Verification email sent. Check inbox and spam folder.',
          };
        }

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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final devOtp = data['devOtp'] as String?;
        final warning = data['warning'] as String?;

        return {
          'success': 'true',
          'error': null,
          if (devOtp != null) 'mockOtp': devOtp,
          if (warning != null) 'warning': warning,
        };
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final message = errorData['message'] as String? ?? 'Failed to send OTP';
      return {'success': null, 'error': message};
    } catch (e) {
      final message = e.toString();
      if (message.contains('too-many-requests') ||
          message.contains('quota-exceeded')) {
        await _ensureMockUsersLoaded();
        await _ensureMockOtpsLoaded();

        if (!_mockUsers.containsKey(normalizedEmail)) {
          _mockUsers[normalizedEmail] = {
            'password': 'Temp@1234',
            'name': 'Recovered User',
            'isVerified': 'false',
          };
          await _persistMockUsers();
        }

        final otp = _generateOtpCode();
        _pendingMockOtps[normalizedEmail] = otp;
        await _persistMockOtps();

        return {
          'success': 'true',
          'error': null,
          'delivery': 'mock',
          'mockOtp': otp,
          'warning': 'Firebase is rate-limited on this device. Using demo OTP fallback.',
        };
      }
      return {'success': null, 'error': 'Network error: $message'};
    }
  }

  static Future<Map<String, String?>> verifyRegistrationOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      if (USE_MOCK_AUTH) {
        if (usesFirebaseEmailVerification && await _ensureFirebaseReady()) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null ||
              currentUser.email?.trim().toLowerCase() != normalizedEmail) {
            return {
              'success': null,
              'error': 'Registration session expired. Please sign up again.',
            };
          }

          await currentUser.reload();
          final refreshedUser = FirebaseAuth.instance.currentUser;
          if (refreshedUser == null || !refreshedUser.emailVerified) {
            return {
              'success': null,
              'error': 'Email not verified yet. Click the verification link sent to your email.',
            };
          }

          await _ensureMockUsersLoaded();
          final user = _mockUsers[normalizedEmail];
          if (user != null) {
            user['isVerified'] = 'true';
            await _persistMockUsers();
          }

          return {'success': 'true', 'error': null};
        }

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
        final restored = await _restoreSessionIfNeeded();
        if (!restored) {
          return false;
        }
      }

      // Check if token has expired
      if (DateTime.now().isAfter(_tokenExpiry!)) {
        _authToken = null;
        _tokenExpiry = null;
        _currentUserIdentifier = null;
        await _clearPersistedSession();
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
        _currentUserIdentifier = null;
        await _clearPersistedSession();
        return false;
      }
    } catch (e) {
      _authToken = null;
      _tokenExpiry = null;
      _currentUserIdentifier = null;
      await _clearPersistedSession();
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
        _currentUserIdentifier = null;
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
      _currentUserIdentifier = null;
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

  /// Start a guest session for users who skip login/signup.
  static Future<void> startGuestSession() async {
    final guestToken =
        '$_guestSessionPrefix${DateTime.now().millisecondsSinceEpoch}';
    _authToken = guestToken;
    _tokenExpiry = DateTime.now().add(const Duration(days: 7));
    _currentUserIdentifier = 'guest';
    await _persistSession();
  }

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
      await _clearPersistedSession();
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
        await _persistSession();
        return {'token': token, 'error': null};
      } else {
        _authToken = null;
        _tokenExpiry = null;
        _currentUserIdentifier = null;
        await _clearPersistedSession();
        return {'token': null, 'error': 'Token refresh failed'};
      }
    } catch (e) {
      _authToken = null;
      _tokenExpiry = null;
      _currentUserIdentifier = null;
      await _clearPersistedSession();
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
        if (usesFirebaseEmailVerification && await _ensureFirebaseReady()) {
          try {
            await FirebaseAuth.instance.sendPasswordResetEmail(
              email: normalizedEmail,
            );
            return {
              'success': 'true',
              'error': null,
              'delivery': 'firebase',
              'warning': 'Password reset link sent to your email.',
            };
          } on FirebaseAuthException catch (e) {
            if (e.code == 'user-not-found') {
              return {
                'success': null,
                'error': 'User not found. Please sign up first.',
              };
            }
            return {
              'success': null,
              'error': e.message ?? 'Failed to send reset email',
            };
          }
        }

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

        return {
          'success': 'true',
          'error': null,
          'delivery': 'mock',
          'mockOtp': otp,
        };
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final devOtp = data['devOtp'] as String?;
        final warning = data['warning'] as String?;

        return {
          'success': 'true',
          'error': null,
          'delivery': 'backend',
          if (devOtp != null) 'mockOtp': devOtp,
          if (warning != null) 'warning': warning,
        };
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
