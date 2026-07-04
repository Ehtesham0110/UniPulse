# UniPulse

UniPulse is a multi-college campus events platform built with Flutter and Node.js.

This repository is organized as a monorepo:

- `apps/mobile`: Flutter mobile application.
- `apps/backend`: Node.js API using Express and MongoDB.
- `docs`: Architecture, API, and schema notes.

## Current Phase

Phase 1 implements the production architecture foundation:

- Multi-college data ownership through `collegeId`.
- Roles and permissions for Student, Organizer, Admin, and Super Admin.
- Clubs as first-class event owners.
- Event lifecycle and approval workflow.
- Team, attendance, QR, certificate, notification, analytics, and branding schemas.
- Flutter feature-first structure with branded theme foundations and UI shell.

## Run Backend

```bash
cd apps/backend
npm install
npm run dev
```

Create `apps/backend/.env` from `.env.example` before connecting to external services.

## Run Mobile

```bash
cd apps/mobile
flutter pub get
flutter run
```

