# Changelog

All notable changes to UniPulse are documented in this file.

## [Unreleased]

### Added — Phase 2 kickoff: Registrations module
- Backend `registrations` module: create individual/team registration,
  list my registrations, list an event's registrations (organizer/admin).

## 2026-07-05 — Phase 1: Authentication milestone complete

### Fixed (security)
- **Critical:** `/auth/firebase-login` previously trusted a client-supplied
  `phone` field with no verification, allowing anyone to log in as any
  phone number. It now requires a Firebase ID token and verifies it
  server-side via `firebase-admin`; the phone number is read only from the
  verified token claim.
- Fixed a Firebase Admin SDK integration bug caught during build
  verification: `firebase-admin` v14 removed the legacy
  `admin.credential.cert(...)` namespaced API from the default export.
  Switched to the modular API (`firebase-admin/app`, `firebase-admin/auth`)
  used by v9+.

### Added — Backend
- `src/config/firebase.js`: Firebase Admin initialization + ID token
  verification helper.
- `POST /api/auth/refresh`: exchange a refresh token for a new access
  token (silent/auto login).
- `GET /api/auth/me`: fetch the current authenticated user + college
  (used by the app on startup to decide login vs. home).

### Added — Flutter
- Real Firebase phone-number OTP sign-in (`firebase_auth`), replacing
  non-functional static UI.
- Riverpod auth state management: `AuthController` drives sendOtp →
  verifyOtp → backend session exchange → secure token storage.
- Secure on-device token storage (`flutter_secure_storage`) and a Dio
  `ApiClient` that attaches the access token to every request and
  transparently refreshes it on a 401.
- Functional Login and Signup forms (previously plain `Text` widgets with
  no input capability) with branch/year selection.
- New "Complete Your Profile" screen for first-time users who verify OTP
  from the Login tab before providing signup details.
- Auto-login on app start: splash screen checks for a stored session and
  routes straight to Home if valid.
- Router-level auth guarding: `GoRouter` redirect logic (Riverpod-aware)
  keeps unauthenticated users off protected routes and bounces
  authenticated users away from auth screens.

### Verified
- All backend source files pass `node --check`.
- Full Express app boots cleanly with all routes/controllers wired
  (`createApp()` succeeds with no import errors).
- Live server smoke test: `/health`, `/api/auth/firebase-login`,
  `/api/auth/refresh`, `/api/auth/me` all return correct status codes and
  structured error bodies for invalid/missing credentials.
- Confirmed refresh-token JWT verification logic is correct (a
  structurally valid token passes `jwt.verify` and proceeds to the DB
  lookup; it does not incorrectly reject on signature/expiry).
- **Not verified in this environment** (no Flutter SDK, no network, no live
  MongoDB available in the sandbox): `flutter analyze`, `flutter pub get`,
  a real device/emulator run, and any DB-backed request path end-to-end.
  See `AI_HANDOVER.md` → Known Issues for what the developer still needs
  to run locally before shipping.
