# Changelog

All notable changes to UniPulse are documented in this file.

## [Unreleased]

Nothing yet — Registration milestone is complete. See below for what's next.

## 2026-07-05 (2) — Phase 2 milestone: Registration complete

### Added — Backend
- `registrations` module: `registration.controller.js` + `registration.routes.js`,
  mounted at `/api/registrations`.
- `POST /api/registrations`: register for an event as an individual or as a
  team leader. Validates:
  - Event exists and belongs to the caller's college.
  - Event's lifecycle is `Registration Open` and the registration window
    (`registrationEnd`) hasn't passed.
  - No existing non-cancelled registration for this student + event
    (duplicate prevention).
  - For team events: team size (leader + members) is within
    `[event.teamMin, event.teamMax]`, every member has a name and phone,
    and a team name is provided. Creates `Team` + `TeamMember` documents.
  - Event capacity: free events are confirmed with an atomic
    `findOneAndUpdate` capacity check ($expr comparing `currentParticipants`
    to `maximumParticipants`) to prevent overselling under concurrent
    requests; paid events are created as `Pending Payment` and do **not**
    consume a capacity slot (payment integration is a separate, later
    milestone).
  - Issues a QR token: a random token is generated, only its SHA-256 hash
    is stored (`qrTokenHash`) on the registration; the raw token is
    returned once in the response. (Actual QR image generation/scanning is
    out of scope for this milestone — see Pending Work.)
- `GET /api/registrations/me`: list the current user's registrations,
  with the event populated.
- `GET /api/registrations/event/:eventId`: list all registrations for an
  event (organizer/admin only, via `requirePermission(VIEW_PARTICIPANTS)`).
- `PATCH /api/registrations/:id/cancel`: cancel a registration; decrements
  event capacity if it had been confirmed; marks any associated team as
  Cancelled; rejects cancelling an already-cancelled or already-attended
  registration.
- `apps/backend/test/registration.verify.mjs`: a mock-backed verification
  script (no live MongoDB available in this sandbox) that exercises the
  real controller functions against in-memory fakes of the Mongoose model
  calls used. 16/16 checks pass — see Verified section below.

### Added — Flutter
- `features/events/domain/event_summary.dart` + `features/events/data/event_api.dart`:
  minimal event fetch (`GET /events/:id`), just enough to drive registration
  decisions (individual vs team, price, team size bounds, capacity, lifecycle).
  Full Events-feature API integration (listing, create/edit, gallery, etc.)
  is still Phase 3/4 and intentionally not touched here.
- `features/registration/domain/registration_models.dart`,
  `features/registration/data/registration_api.dart`,
  `features/registration/application/registration_providers.dart`: typed
  models, API client, and Riverpod state for registering, listing "my
  registrations", and cancelling.
- `registration_sheet.dart` (rewritten): now a real, functional form —
  dynamic team-size selector bounded by the event's actual `teamMin`/`teamMax`,
  dynamic member name/phone fields, team name field, real submit flow with
  loading state, inline + snackbar error messages for every backend
  validation case (duplicate, full, wrong team size, registration closed),
  and a success snackbar + auto-close on confirmation. Replaces the fully
  static "Treasure Hunt" mock with the real event's data.
- `event_detail_screen.dart` (rewritten): now takes a real `eventId`,
  fetches the event, shows a loading state and a friendly error state,
  and disables/labels the Register button correctly when the event is
  full, not open, or the user is already registered. Cosmetic-only
  sections (Schedule/Gallery/Organizer placeholders) were intentionally
  left as static placeholders — wiring those to real data is Phase 3/4
  Events work, out of scope for this milestone.
- `my_events_screen.dart` (rewritten): now shows the user's real
  registrations (upcoming/past), with pull-to-refresh, empty state, error
  state, and a cancel action (with confirmation dialog) for confirmed
  upcoming registrations.
- `app/router/app_router.dart`: `/event/:id` now passes the real path
  parameter into `EventDetailScreen`.
- `core/utils/date_formatting.dart` (new): tiny dependency-free date
  formatter, used instead of adding the `intl` package, since `flutter pub
  get` can't be run in this sandbox to verify a new dependency resolves
  cleanly.

### Verified
- All backend files (including the new registrations module and the test
  script) pass `node --check`.
- Full Express app boots cleanly with the registrations router mounted.
- Live server smoke test: `POST /api/registrations`, `GET /api/registrations/me`,
  and `PATCH /api/registrations/:id/cancel` all correctly return 401 without
  a token (auth guard confirmed wired correctly).
- **`apps/backend/test/registration.verify.mjs`**: 16/16 checks pass,
  covering individual registration, QR token issuance, capacity increment,
  duplicate prevention, capacity-limit rejection, team-too-small rejection,
  team-too-large rejection, successful team registration with correct
  leader+member records, `listMyRegistrations`, `listEventRegistrations`,
  cancellation, capacity decrement on cancellation, double-cancel
  rejection, slot re-fill after cancellation, and paid-event
  Pending-Payment behavior.
- All new/changed Dart files: verified brace/paren balance, verified every
  relative import resolves to a real file, and manually cross-checked
  every referenced provider/class/field (`apiClientProvider`,
  `authControllerProvider`, `AppUser` fields, `GradientButton` constructor,
  `CampusTreeFooter` constructor) against its actual definition.
- **Not verified in this environment**: `flutter analyze` and
  `flutter pub get` (no Flutter SDK in this sandbox), and no run on a real
  device/emulator/live MongoDB. See `AI_HANDOVER.md` → Known Issues.

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
