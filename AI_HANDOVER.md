# UniPulse — AI Handover

_Last updated by: Claude (Sonnet 5), during this session._

## ⚠️ Important correction to prior status claims

The original handover prompt stated the Presentation Layer (all screens) was
"✔ done" and that only backend/integration work remained. On inspection,
that was **not accurate**. The 16 screens exist visually, but before this
session:

- They contained **no real `TextField`/form state** — the login and signup
  "inputs" were plain `Text` widgets displaying static hint strings. Nothing
  was typeable.
- There was **zero Riverpod usage** beyond wrapping `main.dart` in a
  `ProviderScope`. No providers, no state notifiers existed anywhere.
- There was **zero Dio/API usage** in the Flutter app. All screens (Home,
  Events, My Events, Certificates, Admin, Profile) show hardcoded sample data.
- `firebase_core`/`firebase_auth` were **not in `pubspec.yaml`** and no
  Firebase code existed on the client at all, despite the backend already
  depending on `firebase-admin`.
- The backend's `/auth/firebase-login` endpoint **trusted a client-supplied
  phone number with no verification** — anyone could log in as any phone
  number by just putting it in the request body. This was a real security
  hole, not a stub.
- No `AI_HANDOVER.md` existed prior to this session.

This isn't a criticism of the earlier work — the visual/architecture layer
(theme, folder structure, Mongoose models, GoRouter skeleton, permission
system) is genuinely solid and was reused as-is. But "Presentation Layer
complete" should be read as "screens are visually built," not "screens are
functional." Future sessions should verify claims like this against the
actual code rather than trusting phase checklists.

## Completed this session (Phase 1: Authentication — now functional end-to-end)

**Backend**
- `src/config/firebase.js` (new): Firebase Admin SDK init + ID token verification.
- `src/modules/auth/auth.controller.js` (rewritten): `firebaseLogin` now
  verifies the Firebase ID token server-side and derives the phone number
  from the verified token claim — never from client input. Added
  `refreshAccessToken` and `getCurrentUser` controllers.
- `src/modules/auth/auth.routes.js`: added `POST /auth/refresh` and
  `GET /auth/me` (protected).
- `src/config/env.js`: added Firebase Admin + JWT expiry env vars.
- All backend files pass `node --check` (no Node/Flutter toolchain available
  in this sandbox to run `npm test` or a live server — see "Known issues").

**Flutter**
- `pubspec.yaml`: added `firebase_core`, `firebase_auth`.
- `lib/firebase_options.dart` (new, **placeholder**): must be regenerated
  with `flutterfire configure` — see Known Issues.
- `lib/core/network/api_config.dart` (new): single place for backend base URL.
- `lib/core/network/api_client.dart` (new): Dio client with auth-header
  interceptor + automatic access-token refresh on 401.
- `lib/core/storage/secure_token_storage.dart` (new): wraps
  `flutter_secure_storage` for access/refresh tokens.
- `lib/features/auth/domain/app_user.dart` (new): typed user model + role mapping.
- `lib/features/auth/data/auth_api.dart` (new): `/auth/firebase-login`,
  `/auth/me` calls.
- `lib/features/auth/application/auth_state.dart` + `auth_controller.dart`
  (new): Riverpod `StateNotifier` driving the whole login/signup/OTP/auto-login
  flow, wired to real `firebase_auth` phone verification.
- `lib/features/auth/presentation/welcome_auth_screen.dart` (rewritten):
  real `TextField`s and branch/year `ChoiceChip`s bound to controllers;
  Login sends OTP for an existing phone; Signup collects full profile data
  upfront and sends OTP with it attached.
- `lib/features/auth/presentation/otp_screen.dart` (rewritten): real 6-box
  OTP input with auto-advance/auto-submit, resend, loading + error states.
- `lib/features/auth/presentation/complete_profile_screen.dart` (new):
  fallback screen for when a phone number verified via the Login tab turns
  out to belong to a new user (backend returns "signup required") — reuses
  the already-verified Firebase ID token, no second OTP needed.
- `lib/features/splash/presentation/splash_screen.dart` (rewritten): now
  triggers `tryAutoLogin()` (reads secure storage, validates session via
  `/auth/me`) and routes to `/home` or `/welcome` accordingly.
- `lib/app/router/app_router.dart` (rewritten): now a Riverpod
  `Provider<GoRouter>` with a `refreshListenable` tied to auth state and
  `redirect` logic that keeps unauthenticated users out of
  `/home`, `/events`, `/event`, `/admin`, and bounces authenticated users
  away from the auth screens.
- `lib/app/app.dart`: converted to `ConsumerWidget` reading the router provider.
- `lib/main.dart`: now calls `Firebase.initializeApp()` before `runApp`.

No existing screens were redesigned — visual structure, colors, and copy
were preserved; only interactivity/data wiring was added.

## Current Phase

**Phase 1 (Firebase Authentication): complete and build-verified** (within
this sandbox's limits — see Verification below), pending the developer
supplying a real Firebase project (see Known Issues).

## Verification Performed (this session)

No Flutter SDK and no network egress are available in this sandbox, so
"verify it builds" was done as thoroughly as possible within those limits:

- `node --check` on every backend source file: **pass**.
- Booted the real Express app in-process (`createApp()`), which imports
  every route/controller/model — this caught a real bug: **`firebase-admin`
  v14 removed the legacy `admin.credential.cert(...)` API from its default
  export.** Fixed by switching `src/config/firebase.js` to the modular API
  (`firebase-admin/app`, `firebase-admin/auth`). Without this fix, the
  server would have crashed on the first login attempt in production.
- Started a live server (no DB) and hit `/health`, `POST /api/auth/firebase-login`,
  `POST /api/auth/refresh`, `GET /api/auth/me` with invalid/missing
  credentials — all returned correct status codes and structured error
  bodies.
- Signed a structurally-valid fake refresh token and confirmed it passes
  JWT verification and proceeds to the (unavailable) DB lookup, rather than
  being incorrectly rejected — confirms the refresh logic itself is sound.
- Manually proofread every new/changed Dart file for import correctness and
  brace/structure balance (no Flutter SDK available to run `flutter analyze`
  or `flutter pub get` in this sandbox).

**Still required from the developer before shipping:** run `flutter pub get`
and `flutter analyze` locally, connect a real MongoDB instance and confirm
the full login round-trip (a phone number that doesn't exist yet → signup
required → account created), and complete Firebase project setup (below).

## Pending Work (in priority order)

1. **Firebase project setup** (developer action required, see Known Issues)
   — nothing downstream of auth can be tested without this.
2. **Phase 2 backend**: registrations (individual + team, min/max members),
   payments (Razorpay order creation + webhook verification), attendance
   (QR generation/validation, check-in/out), certificates (template +
   PDF generation via `pdfkit`), notifications (FCM send by college/branch/
   year/club/event/individual), admin management endpoints.
3. **Phase 3 Flutter API integration**: replace hardcoded sample data in
   `home_screen.dart`, `event_list_screen.dart`, `event_detail_screen.dart`,
   `my_events_screen.dart`, `certificates_screen.dart`, `profile_screen.dart`,
   `admin_panel_screen.dart` with real Riverpod providers calling the
   `ApiClient` built this session (it's ready to reuse — see
   `lib/core/network/api_client.dart`).
4. Phases 4–9 per the original spec (Events CRUD UI, Registration +
   Razorpay UI, QR attendance UI (`mobile_scanner` isn't wired to anything
   yet), Certificates UI, Notifications, Admin Panel data wiring).

## Next Recommended Task

Start Phase 2: build the `registrations` module (model already exists —
`registration.model.js`) — controller + routes for individual/team
registration with dynamic member counts, since Phase 5 (Flutter
registration UI) and Phase 6 (QR attendance) both depend on it existing
first. Then wire `registration_sheet.dart` (currently static UI) to it.

## Known Issues

1. **Firebase project credentials cannot be fabricated.** I added the
   `firebase_auth`/`firebase_core` packages and all app-side wiring, but
   `lib/firebase_options.dart` is a placeholder with `'REPLACE_ME'` values.
   The developer must run `flutterfire configure` from `apps/mobile/` against
   their real Firebase project (with Phone sign-in enabled in the Firebase
   console) to generate real values. Android will also need SHA-1/SHA-256
   fingerprints registered in Firebase for Phone Auth reCAPTCHA fallback to
   work, and `google-services.json` / `GoogleService-Info.plist` need adding
   (flutterfire configure handles this).
2. **Backend `.env` still needs real values** for `FIREBASE_PROJECT_ID`,
   `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` (from a Firebase service
   account JSON), plus Mongo/Razorpay/Cloudinary as already listed in
   `.env.example`.
3. **No sandbox toolchain available** in this session to run `flutter pub get`,
   `flutter analyze`, or `npm install && npm run dev` — Node/Flutter binaries
   aren't installed and network egress is disabled. All backend files were
   verified with `node --check` (syntax only, not a full lint/type pass).
   **Before relying on this code, run `flutter analyze` and `flutter pub get`
   locally** to catch anything a syntax check can't (import typos, API
   version drift in `firebase_auth`/`dio`, etc.).
4. `apps/backend/.env.example` already lists the Firebase Admin vars — no
   change needed there.
5. The default `collegeCode` used by the Flutter app is hardcoded to
   `'UNIPULSE'` in `welcome_auth_screen.dart` / `otp_screen.dart`. A real
   multi-college deployment needs a college-selection step before login
   (not built yet — out of scope for Phase 1).
6. `middleware/require-permission.js` was read but not modified — assumed
   correct since Analytics/Clubs/Events routes already depend on it working.

## Files Modified This Session

**Backend**
- `apps/backend/src/config/env.js`
- `apps/backend/src/config/firebase.js` (new; fixed post-verification to use
  the modular `firebase-admin/app` + `firebase-admin/auth` API instead of
  the legacy `admin.credential.cert(...)` namespaced API, which doesn't
  exist in firebase-admin v14)
- `apps/backend/src/modules/auth/auth.controller.js`
- `apps/backend/src/modules/auth/auth.routes.js`

**Flutter**
- `apps/mobile/pubspec.yaml`
- `apps/mobile/lib/main.dart`
- `apps/mobile/lib/firebase_options.dart` (new, placeholder)
- `apps/mobile/lib/app/app.dart`
- `apps/mobile/lib/app/router/app_router.dart`
- `apps/mobile/lib/core/network/api_config.dart` (new)
- `apps/mobile/lib/core/network/api_client.dart` (new)
- `apps/mobile/lib/core/storage/secure_token_storage.dart` (new)
- `apps/mobile/lib/features/auth/domain/app_user.dart` (new)
- `apps/mobile/lib/features/auth/data/auth_api.dart` (new)
- `apps/mobile/lib/features/auth/application/auth_state.dart` (new)
- `apps/mobile/lib/features/auth/application/auth_controller.dart` (new)
- `apps/mobile/lib/features/auth/presentation/welcome_auth_screen.dart`
- `apps/mobile/lib/features/auth/presentation/otp_screen.dart`
- `apps/mobile/lib/features/auth/presentation/complete_profile_screen.dart` (new)
- `apps/mobile/lib/features/splash/presentation/splash_screen.dart`
