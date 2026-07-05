# Changelog

All notable changes to UniPulse are documented in this file.

## [Unreleased]

Nothing yet — Events milestone is complete. Payments is next (not started).

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
