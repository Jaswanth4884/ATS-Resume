# Resume Builder Auth Backend (OTP + Email)

This backend provides authentication + OTP email flows for your Flutter app.

## Endpoints

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/verify`
- `POST /auth/logout`
- `POST /auth/send-registration-otp`
- `POST /auth/verify-registration-otp`
- `POST /auth/password-reset/send-otp`
- `POST /auth/password-reset/verify-otp`
- `POST /auth/password-reset/change`

## Setup

1. Copy `.env.example` to `.env`
2. Fill SMTP and JWT values
3. Install packages:
   - `npm install`
4. Run server:
   - `npm start`

## Frontend base URL

In your Flutter app, set `_baseUrl` in `lib/services/auth_service.dart` to:

- `http://localhost:3000`

(Use your deployed backend URL in production.)
