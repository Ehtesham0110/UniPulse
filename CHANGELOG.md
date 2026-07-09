# Changelog

All notable changes to UniPulse are documented in this file.

## [Unreleased]

Nothing yet — QR Attendance milestone is complete. Certificates is next (not started).

## 2026-07-06 — QR Attendance milestone complete

### Fixed (design gap enabling this milestone)
- **QR tokens are now deterministic instead of random.** Previously
  (Session 2), a registration's QR token was `crypto.randomBytes(24)` —
  only its SHA-256 hash was ever stored, and the raw token was returned
  exactly once, at registration creation. That made it **impossible** to
  redisplay a registration's QR code later (e.g. in "My Events" after
  closing the app), since the server had no way to reproduce it. QR
  tokens are now `HMAC-SHA256(registrationId, QR_SIGNING_SECRET)` —
  deterministic and regenerable on demand from just the registration id,
  while still being stored only as a hash and still being unguessable
  without the server's signing secret. `registerForEvent` (Session 2,
  unmodified otherwise) now pre-generates the registration's `_id` so the
  token can be built before the document is created.

### Added — Backend
- `src/shared/utils/qr-token.js` (new): `buildQrToken`/`extractRegistrationId`
  — the deterministic signing/verification logic above, using
  `crypto.timingSafeEqual` for signature comparison.
- `QR_SIGNING_SECRET` added to env config (falls back to the JWT access
  secret in dev so the app still boots without extra config).
- `GET /api/registrations/:registrationId/qr` (new): returns the
  regenerated QR token for the caller's own registration. Only succeeds
  for `Confirmed`/`Attended`/`Completed` registrations — returns 409 with
  `reason: NO_QR_AVAILABLE` for `Pending Payment`, and 404 for anything
  else (including `Cancelled`, and registrations belonging to someone
  else).
- New `attendance` module, mounted at `/api/attendance` (all three routes
  gated by the existing `MARK_ATTENDANCE` permission — Organizer and
  Super Admin, not plain Admin):
  - `POST /api/attendance/validate`: resolves a scanned QR token to its
    registration/event/student without mutating anything, so the
    organizer app can show "who is this" before committing to an action.
    Rejects invalid/tampered tokens, cancelled registrations, unpaid
    (`Pending Payment`) registrations, a QR scanned at the wrong event,
    and events that have ended/been cancelled — each with a distinct
    `details.reason` code for the UI to key off.
  - `POST /api/attendance/check-in`: creates or updates the `Attendance`
    record (`checkedIn`, `checkInTime`, `scannedBy`, `scannerDevice`),
    and transitions the registration from `Confirmed` to `Attended`.
    **Prevents duplicate scans:** rejects with `ALREADY_CHECKED_IN` (409)
    if already checked in, including the original check-in time in the
    error for context.
  - `POST /api/attendance/check-out`: requires a prior check-in
    (`NOT_CHECKED_IN` if not); **prevents duplicate scans** the same way
    (`ALREADY_CHECKED_OUT`).
- `apps/backend/test/attendance.verify.mjs` (new): mock-backed harness
  (no live MongoDB in this sandbox) exercising the real, unmodified
  controller functions, including the real HMAC-based QR token logic
  (not mocked — only the Mongoose model calls are). **17/17 checks pass.**

### Added — Flutter
**Student side:**
- `registration_api.dart`: added `fetchQrToken(registrationId)`.
- `registration_providers.dart`: added `registrationQrProvider` (family by
  registrationId).
- `MyRegistration`: added `hasQrCode` getter mirroring the backend's
  eligibility rule (Confirmed/Attended/Completed only — never for
  Cancelled or Pending Payment).
- `qr_code_sheet.dart` (new): bottom sheet rendering the QR code via
  `qr_flutter` (new dependency — see Verified below), with loading/error
  states for the fetch.
- `my_events_screen.dart`: registration cards now show a QR button when
  `hasQrCode` is true. Because My Events already refreshes automatically
  after a successful payment (wired in the Payments milestone) and after
  cancellation, the QR button correctly appears/disappears without any
  extra wiring needed this session.

**Organizer side:**
- New `features/attendance/` (domain/data/application): `ScannedAttendee`
  model, `AttendanceApi` (validate/checkIn/checkOut) with error mapping
  that preserves the backend's `reason` code, `attendanceApiProvider`.
- `qr_scanner_screen.dart` (rewritten from a fully static mock): real
  camera scanning via `mobile_scanner` (already a pubspec dependency,
  unused until now), with a state machine (scanning → validating →
  attendee info → action loading → success/failure) that:
  - shows a viewfinder overlay while scanning, and ignores further scans
    while one is already being processed or acted on (prevents
    double-submits from the camera firing multiple detections of the
    same code);
  - displays attendee info (name, roll number, branch, event, current
    attendance status) with Check In / Check Out buttons that
    enable/disable based on current state;
  - shows a distinct amber "Duplicate Scan" style (vs. red for other
    errors) for `ALREADY_CHECKED_IN`/`ALREADY_CHECKED_OUT`, and specific
    titles for every other `reason` code (Invalid QR Code, Registration
    Cancelled, Payment Pending, Wrong Event, Event Ended, Not Checked In);
  - shows a success state with a small pop-in checkmark animation and a
    "Scan Next" action to resume the camera.
  - Role-gated: students (who lack `MARK_ATTENDANCE`) see a friendly
    "not available for your role" screen instead of requesting camera
    access for a scanner they can't use.

### Verified
- All backend files pass `node --check`; full app boot with the
  attendance router mounted alongside auth/events/registrations/payments;
  live HTTP checks confirm attendance routes are correctly mounted and
  auth-guarded.
- `apps/backend/test/attendance.verify.mjs`: **17/17** checks pass —
  QR token round-trip (issue → extract → matches original registration
  id), tampered-signature rejection, malformed-token rejection,
  `getRegistrationQr` regenerating the identical token and refusing
  `Pending Payment`, `validateQr` happy path + wrong-event rejection,
  check-in happy path (including the `Confirmed` → `Attended`
  transition), duplicate check-in rejection, cancelled/pending-payment/
  event-ended rejection, check-out-before-check-in rejection, check-out
  happy path, and duplicate check-out rejection.
- **All previous suites re-run with no regressions:**
  `registration.verify.mjs` 16/16, `events.verify.mjs` 23/23,
  `payments.verify.mjs` 18/18. **74/74 backend checks pass in total
  across all four modules.**
- Flutter: every relative import/export verified to resolve to a real
  file; every new/changed symbol (`ScannedAttendee` fields,
  `attendanceApiProvider`, `canScanAttendance`, `AttendanceApi` methods)
  manually cross-checked against its definition. **`flutter analyze`/
  `flutter pub get` could not be run** — no Flutter SDK is available in
  this sandbox (unchanged from every prior session). **One new pub
  dependency was added:** `qr_flutter` (pure-Dart, minimal transitive
  deps, no platform channels) — needed to actually render a scannable QR
  image on the student side; there was no way to satisfy "Display QR
  inside My Events" without it. `mobile_scanner` was already in
  `pubspec.yaml` from the original scaffold but had zero usage before
  this session.

## 2026-07-05 (4) — Payments milestone: Razorpay integration complete

### Added — Backend
- New `payments` module mounted at `/api/payments`:
  - `POST /api/payments/orders`: creates (or idempotently reuses) a
    Razorpay order for a registration that is `Pending Payment`. Verifies
    the registration belongs to the caller, the event actually requires
    payment, and — since paid-event registrations weren't capacity-limited
    at creation time (a gap from the Registration milestone) — enforces
    event capacity here, before money changes hands. Calling this again
    before paying reuses the existing unpaid order instead of creating a
    duplicate Razorpay order.
  - `POST /api/payments/verify`: verifies the standard Razorpay HMAC-SHA256
    signature (`order_id|payment_id` signed with the key secret). On a
    valid signature: marks the payment `Paid`, moves the registration
    `Pending Payment` → `Confirmed`, and atomically increments the event's
    `currentParticipants` — capacity is only ever consumed after a real,
    verified payment. **Idempotent:** calling this again for an
    already-`Paid` payment returns success without reprocessing, so a
    network retry from the Flutter client can never double-increment
    capacity or double-confirm anything. A bad/tampered signature is
    rejected (400) without mutating any state, since it could be a
    transient client bug rather than a genuine failure.
  - `POST /api/payments/:paymentId/fail`: reports a failed or
    user-cancelled checkout. Marks only that payment attempt `Failed`; the
    registration stays `Pending Payment` so the student can retry (a
    fresh order is created next time, since `createOrder` only reuses
    `Created` — not `Failed` — payments). Refuses to mark an already-`Paid`
    payment as failed.
  - `src/config/razorpay.js` (new): lazy Razorpay SDK client init, mirrors
    the `firebase.js` pattern from the Authentication milestone.
- `apps/backend/test/payments.verify.mjs` (new): mock-backed verification
  harness (no live MongoDB or Razorpay API access in this sandbox) —
  mocks the Mongoose model calls and the Razorpay SDK's `orders.create`
  call, then runs the real, unmodified controller functions. 18/18 checks
  pass.

### Added — Flutter
- `features/payments/domain/payment_order.dart`, `data/payment_api.dart`,
  `application/payment_providers.dart` (new): typed order model and API
  client for the three payment endpoints.
- `registration_api.dart`: `register()` now returns the full
  `NewRegistration` (id + status), not just the QR token, since the
  payment flow needs the registration id to create an order.
- `registration_sheet.dart`: after registering for a paid event (status
  `Pending Payment`), creates a Razorpay order and opens the native
  Razorpay checkout (`razorpay_flutter`, already a dependency). Bridges
  the SDK's event-callback API (`EVENT_PAYMENT_SUCCESS`/`_ERROR`/
  `EVENT_EXTERNAL_WALLET`) into an awaitable result via a `Completer` so
  the existing async submit flow didn't need restructuring. On success,
  verifies the payment with the backend, refreshes the shared
  registrations provider, and returns to the **My Events** tab with a
  success snackbar. On failure/cancellation, reports it to the backend
  (`failPayment`, best-effort) and shows an inline retryable error without
  closing the sheet. Distinct loading labels ("Registering…" → "Opening
  payment…" → "Waiting for payment…") reflect exactly what's happening.
- `features/home/application/home_tab_provider.dart` (new) +
  `home_shell.dart` (converted to `ConsumerStatefulWidget`): a shared
  `homeTabIndexProvider` lets the payment success flow programmatically
  switch to the My Events tab from outside the shell widget, satisfying
  "return to My Events after successful payment."

### Verified
- All backend files (including the new payments module and test) pass
  `node --check`; full app boot with the payments router mounted; live
  HTTP checks confirm all three payment routes are correctly mounted and
  auth-guarded.
- `apps/backend/test/payments.verify.mjs`: 18/18 checks pass — order
  validation, idempotent order reuse, rejection for non-paid events,
  capacity enforcement at order creation, signature validation
  (missing/unknown-order/tampered), successful verification moving
  `Pending Payment` → `Confirmed` and incrementing capacity exactly once,
  duplicate-verification idempotency (capacity NOT double-incremented),
  fail-then-retry flow, and refusing to fail an already-paid payment.
- `test/events.verify.mjs` (23/23) and `test/registration.verify.mjs`
  (16/16) re-run after the payments changes: no regressions. **57/57
  backend checks pass in total across all three modules.**
- Flutter: every relative import/export verified to resolve to a real
  file; every new/changed symbol (`PaymentOrder`, `PaymentApi` methods,
  `NewRegistration`, `homeTabIndexProvider`) manually cross-checked
  against its definition. **`flutter analyze`/`flutter pub get` could not
  be run** — no Flutter SDK is available in this sandbox. No new pub
  dependency was added (`razorpay_flutter` was already present in
  `pubspec.yaml` from the original project scaffold). See
  `AI_HANDOVER.md` → Known Issues — the Razorpay checkout flow in
  particular should be tested on a real device before relying on it,
  since the native SDK bridge can't be exercised at all without one.

## 2026-07-05 (3) — Events milestone: live events module complete

### Added — Backend
- `event.controller.js` extended to a full CRUD module:
  - `PATCH /api/events/:eventId` (new): update an event. Allowed for
    Admin/Super Admin (`MANAGE_EVENTS`) or the Organizer who created the
    event / is assigned to it (`EDIT_ASSIGNED_EVENT`); rejects other
    students with 403. Validates the same rules as create (partial —
    only present fields are checked), re-validates `clubId` if changed,
    and protects `collegeId`/`createdBy`/`currentParticipants`/`approval`/
    `slug`/`_id` from being overwritten by the request body.
  - `DELETE /api/events/:eventId` (new): Admin/Super Admin only. Refuses
    to delete an event that already has registrations (409) — cancel it
    instead.
  - `POST /api/events/:eventId/bookmark` (new): toggles the current
    user's bookmark on an event, using the `user.bookmarks` field that
    already existed in the schema but had no endpoint wired to it.
  - `listEvents` extended: `search` (case-insensitive regex over
    title/description), `bookmarked=true` filter, and default lifecycle
    visibility — students only see Published/Registration Open/
    Registration Closed/Live/Completed/Archived events by default;
    Draft/Pending Approval/Cancelled events are hidden unless the caller
    is an Organizer/Admin (or explicitly filters by `lifecycle`).
  - `getEvent` extended: returns `isBookmarked` for the current user, and
    hides (404, not 403 — doesn't leak existence) Draft/Pending/Cancelled
    events from students.
  - `createEvent` now actually validates its payload (required fields,
    category/eventType enums, valid date, team size bounds, price > 0 for
    paid events) instead of relying on Mongoose to throw an unformatted
    error, and verifies `clubId` references a real club in the caller's
    college.
- **Bug fixed:** event slug generation (`slugify(title)`) had no
  uniqueness guarantee beyond the title itself, so two events with the
  same title in a college would crash with a raw MongoDB duplicate-key
  error (there's a unique index on `collegeId+slug`). Slugs now include a
  timestamp + random suffix.
- `apps/backend/test/events.verify.mjs` (new): mock-backed verification
  harness (no live MongoDB in this sandbox) exercising the real,
  unmodified controller functions. 23/23 checks pass.

### Added — Flutter
- `EventSummary` extended with full detail fields: `endTime`,
  `isBookmarked`, `bannerUrl`/`thumbnailUrl`/`galleryUrls`, `highlights`,
  `rules`, `schedule` (`EventScheduleItem`), and `organizer`
  (`EventOrganizer`) — so the detail screen can render entirely from one
  backend response.
- `EventApi` extended with `listEvents(EventListQuery)` (category +
  search) and `toggleBookmark(eventId)`.
- New `features/events/application/event_providers.dart`: `eventListProvider`
  (family-keyed by category+search), plus the previously-added
  `eventApiProvider`/`eventDetailProvider` moved here from the
  registration module now that Events is a first-class feature.
  `registration_providers.dart` re-exports these so existing import sites
  didn't need to change.
- `home_screen.dart` (rewritten): real user greeting (name/year/branch/roll
  from the authenticated session), and "Upcoming Highlights" now shows up
  to 3 real upcoming events from the backend with loading/error/empty
  states and working bookmark toggles, instead of one hardcoded card.
- `event_list_screen.dart` (rewritten): backend-driven list filtered by
  category, a debounced search box wired to the backend `search` param, a
  client-side All/Upcoming/Past time filter, loading/error/empty states,
  and cards that navigate using the event's **real MongoDB `_id`** —
  this fixes the gap flagged in the previous milestone's handover, where
  list navigation pushed the event's *title* as a fake id.
- `event_detail_screen.dart`: now renders Highlights, Schedule, Gallery
  (network images with a graceful broken-image fallback), and Organizer
  sections from real backend data when present (previously static
  placeholders), and the bookmark button is now functional.

### Verified
- All backend files pass `node --check`; full app boot with the extended
  events router; live HTTP checks confirm every event route (list, get,
  create, update, delete, approve, bookmark) is correctly mounted and
  auth-guarded.
- `apps/backend/test/events.verify.mjs`: 23/23 checks pass — validation
  (empty payload, bad clubId, bad team size, unpaid-price-required),
  duplicate-title slug collision handling, default lifecycle visibility
  (student vs organizer), category filter, search, invalid category
  rejection, draft-event 404 hiding, bookmark toggle + reflection in
  `getEvent`, update permission (student denied / owner allowed / admin
  override), partial-update validation, and delete guarded by existing
  registrations.
- `apps/backend/test/registration.verify.mjs` re-run after the events
  changes: still 16/16 passing (no regression).
- Flutter: every relative import/export verified to resolve to a real
  file; every new/changed symbol (`EventSummary` fields, `EventListQuery`,
  `toggleEventBookmark`, `AppUser` fields) manually cross-checked against
  its definition. **`flutter analyze` and `flutter pub get` could not be
  run** — no Flutter SDK is available in this sandbox. No new pub
  dependency was added this session (gallery images use `Image.network`,
  already built into Flutter). See `AI_HANDOVER.md` → Known Issues.
- Manual review caught and fixed two real bugs before they shipped: a
  broken string interpolation (`'Search $widget.category events…'` —
  missing braces) in the search hint text, and the slug-collision issue
  above.

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
