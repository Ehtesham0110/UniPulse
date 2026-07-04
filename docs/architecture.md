# UniPulse Architecture

## Platform Model

UniPulse is a true multi-college platform. Every major entity is scoped by `collegeId`, including users, clubs, events, teams, registrations, payments, attendance, certificates, notifications, analytics, and settings.

Each college owns its branding:

- Name
- Logo
- Primary color
- Secondary color
- Address
- Website
- Contact details
- App branding settings

The Flutter app loads the active college branding from the backend and applies it through the theme layer. No separate app build is required for different colleges.

## Roles

Roles are stored in the backend and returned after login. Phone numbers are never used to infer admin access.

| Role | Permissions |
| --- | --- |
| Student | Register for events, view certificates, scan QR, edit own profile |
| Organizer | Create events, edit assigned events, view participants, mark attendance |
| Admin | Full event management, organizer management, notifications, certificates, analytics |
| Super Admin | Everything, admin management, college settings, branding, system configuration |

## Event Ownership

Events belong to clubs. Organizers may be assigned to clubs or specific events. Admins review and approve organizer-created events.

## Event Lifecycle

The lifecycle supports:

- Draft
- Pending Approval
- Published
- Registration Open
- Registration Closed
- Live
- Completed
- Archived
- Cancelled

The approval workflow is enabled at the architecture level:

```text
Organizer creates event -> Admin reviews -> Admin approves -> Published
```

It can be disabled per college through settings.

## Team Model

Team data is normalized:

```text
Team -> Team Members -> Registration
```

Registrations reference a team for team events and directly reference a student for individual events.

## QR Model

Each successful registration gets one unique QR token. The token belongs to exactly one registration and is never reused.

## Certificates

Certificates support templates, automatic PDF generation, manual upload, preview, download, and share. Uploaded PDFs are optional, not the only path.

## Notifications

Notifications support audience targeting by:

- Entire college
- Branch
- Year
- Club
- Event participants
- Individual student

## Analytics

Analytics APIs are shaped for charting:

- Total students
- Active users
- Today's check-ins
- Revenue
- Most popular events
- Branch-wise participation
- Year-wise participation
- Registration trends
- Attendance trends

