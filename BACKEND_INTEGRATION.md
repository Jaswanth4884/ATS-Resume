# Backend Authentication Integration Guide

## Overview
This Flutter app now uses secure backend-authenticated login with token-based session management. No credentials are stored locally except for in-memory tokens.

## Key Features
✅ Backend API-based authentication (no local storage)
✅ JWT token validation on every app load
✅ Session expiry tracking with automatic redirect
✅ Secure logout with server notification
✅ Token refresh capability
✅ Network error handling and timeouts
✅ Proper error messages for user feedback
✅ Guest access option (no authentication required)

## Setting Up Your Backend

### 1. Configure API Base URL
Update `lib/services/auth_service.dart` line 6:
```dart
static const String _baseUrl = 'https://your-backend-api.com';
```

### 2. Required Backend Endpoints

#### Login Endpoint
**POST** `/auth/login`
```json
Request:
{
  "email": "user@example.com",
  "password": "password123"
}

Response (200 OK):
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 3600
}

Response (401 Unauthorized):
{
  "message": "Invalid email or password"
}
```

#### Register Endpoint
**POST** `/auth/register`
```json
Request:
{
  "email": "user@example.com",
  "password": "password123",
  "name": "User Name"
}

Response (201 Created):
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 3600
}

Response (409 Conflict):
{
  "message": "Email already registered"
}
```

#### Verify Token Endpoint
**GET** `/auth/verify`
```
Headers:
Authorization: Bearer <token>

Response (200 OK):
{
  "valid": true,
  "userId": "user-id"
}

Response (401 Unauthorized):
{
  "message": "Invalid or expired token"
}
```

#### Logout Endpoint
**POST** `/auth/logout`
```
Headers:
Authorization: Bearer <token>

Response (200 OK):
{
  "message": "Logged out successfully"
}
```

#### Refresh Token Endpoint
**POST** `/auth/refresh`
```
Headers:
Authorization: Bearer <token>

Response (200 OK):
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 3600
}

Response (401 Unauthorized):
{
  "message": "Cannot refresh token"
}
```

#### Password Reset Endpoint
**POST** `/auth/password-reset`
```json
Request:
{
  "email": "user@example.com"
}

Response (200 OK):
{
  "message": "Reset link sent to email"
}
```

## How It Works

### Login Flow
1. User enters email/password
2. App sends credentials to backend via `AuthService.login()`
3. Backend validates and returns JWT token + expiry time
4. Token stored in memory (not on disk - secure!)
5. App redirects to ResumeHome
6. On app reload, `_validateSession()` checks if token is still valid

### Session Validation
- Every time app loads, it calls `AuthService.validateSession()`
- Checks if token exists and hasn't expired
- If expired or invalid, user redirected to login screen
- Backend `/auth/verify` endpoint confirms token validity

### Logout
- User clicks logout button in app menu
- App calls `AuthService.logout()`
- Sends logout notification to backend
- Clears token from memory
- Redirects to login screen

### Authenticated Requests
Make authenticated API calls using:
```dart
try {
  final response = await AuthService.getAuthenticatedRequest('/user/profile');
  // Handle response...
} catch (e) {
  // Handle "not authenticated" error
}
```

## Security Considerations

### ✅ What We Do Right
- Tokens ONLY stored in memory (cleared on app close)
- Page refresh validation prevents cached login
- Token expiry enforcement
- Secure timeout handling (15s for login, 10s for verify)
- No credentials stored locally
- Backend verification on every session
- Proper error messages without exposing sensitive data

### ⚠️ Best Practices
1. Use HTTPS only (set in your backend URL)
2. Implement strong password requirements
3. Use refresh token rotation for extra security
4. Set appropriate token expiry times (recommended: 1 hour)
5. Implement rate limiting on auth endpoints
6. Log authentication attempts on backend
7. Use secure password hashing (bcrypt, argon2)

## Testing the Integration

### Test Login
1. Click "Sign In" on login screen
2. Enter email and password
3. Should hit your `/auth/login` endpoint
4. If valid, token returned and app navigates to resume builder
5. If invalid, error message shown

### Test Session Validation
1. After login, refresh the app (browser F5 or app restart)
2. App should call `_validateSession()`
3. If token is valid, user stays on resume builder
4. If invalid/expired, redirected to login

### Test Logout
1. Click menu icon (⋮) in top-right of resume builder
2. Select "Logout"
3. Token cleared, redirected to login page

## Troubleshooting

### "Network error" message
- Check if backend API URL is correct
- Check if backend server is running
- Verify network connectivity
- Check for CORS issues if accessing from different domain

### "Invalid response format" error
- Verify backend returns valid JSON
- Check response structure matches expected format
- Ensure `token` field is present in login response

### User stays logged in after refresh
- Backend `/auth/verify` might not be working
- Check token expiry time is being set correctly
- Verify token validation on backend

### Logout not working
- Backend `/auth/logout` endpoint might have error
- Check backend logs for issues
- Token is still cleared on client even if logout fails

## Frontend Usage

### Check if user is authenticated
```dart
bool isLoggedIn = AuthService.isAuthenticated();
```

### Get current token
```dart
String? token = AuthService.getToken();
```

### Refresh token manually
```dart
final result = await AuthService.refreshToken();
if (result['error'] != null) {
  // Handle refresh failure
}
```

## Environment Variables (Recommended)
For production apps, store API URL in environment:
```dart
const String _baseUrl = String.fromEnvironment('API_BASE_URL', 
  defaultValue: 'https://api.yourdomain.com');
```

Then run with:
```bash
flutter run --dart-define=API_BASE_URL=https://your-backend-api.com
```
