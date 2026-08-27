# UniPulse 🎓

> **One platform for every college event.**

UniPulse is a college event management and discovery application built to bring students, event organizers, and college administrators together on a single platform.

The application allows students to discover college events, view event details, register for events, scan event QR codes, receive notifications, view announcements, manage saved events, and access important event contacts.

For organizers and administrators, UniPulse provides tools to create and manage events, publish announcements, send notifications, and manage administrative access.

---

## ✨ Features

### 👨‍🎓 Student Features

* 🔐 Phone number authentication with OTP
* 🏠 Personalized home screen
* 📅 Event Calendar
* 🔎 Browse upcoming college events
* 📖 View complete event details
* 📝 Register for events
* ❤️ Save events for later
* 📷 Scan event QR codes
* 🔔 Receive event notifications
* 📢 View announcements
* 👤 Manage profile
* ⚙️ Application settings
* 📞 View event contacts
* 🚪 Logout

### 📷 QR Code Event Scanner

The QR Scanner is designed to make opening an event as fast as possible.

A student can:

1. Open the QR Scanner.
2. Scan an event QR code.
3. UniPulse identifies the event automatically.
4. The existing Event API retrieves the event.
5. The app opens the corresponding Event Detail screen.
6. The student can continue with the normal registration flow.

Supported QR payload formats include:

* Plain MongoDB Event IDs
* JSON event payloads
* Existing UniPulse QR formats
* Event URLs / deep-link style QR payloads where supported

The scanner also handles invalid QR codes, unavailable events, network failures, camera permissions, and duplicate scans.

---

## 📅 Event Calendar

UniPulse includes a dedicated monthly Event Calendar.

Students can:

* View upcoming events by month
* See which dates contain events
* Select a date
* View events scheduled for that date
* Open an event directly from the calendar
* Navigate to the existing Event Detail screen

The Calendar is accessible from the Home screen while preserving the existing bottom navigation.

---

## 🛠️ Admin Panel

The Admin Panel acts as the central management area for authorized users.

### Admin

Admins can:

* Create events
* Edit events
* Delete events
* Publish events
* Save events as drafts
* Create announcements
* Send notifications

### Super Admin

Super Admins have all Admin permissions plus:

* Add administrators
* Remove administrators
* Change administrator roles
* Manage administrator permissions

Students cannot access the Admin Panel.

---

## 👥 User Roles

UniPulse supports role-based access control.

| Role        | Permissions                                                                            |
| ----------- | -------------------------------------------------------------------------------------- |
| Student     | Discover events, register, scan QR, save events, announcements, notifications, profile |
| Admin       | All Student features + event management, announcements and notifications               |
| Super Admin | All Admin features + administrator management                                          |

The application uses the authenticated user's role to determine which administrative features are available.

---

## 📢 Announcements

Administrators can publish announcements related to college events.

Students can:

* View announcements
* Read event-related updates
* Filter announcements by event

This allows students to quickly find updates related to a specific event.

---

## 🔔 Notifications

UniPulse supports event and administrative notifications.

Notifications can be used for:

* New events
* Registration updates
* Event reminders
* Important announcements

Future notification functionality will also support targeted reminders for registered participants.

---

## 👤 Profile

The Profile section provides students with access to their account information and application features.

### Personal Information

Users can manage:

* Name
* Roll Number
* Email
* Date of Birth
* Other personal details

### Saved Events

Students can view events they have saved for later.

### Settings

Current settings include:

* Light Mode
* Dark Mode

Additional settings can be added in future releases.

### Event Contacts

Students can access important contacts associated with events, including:

* Event Head
* Organizer
* Treasurer
* Coordinator
* Contact Number

### Admin Panel

The Admin Panel option is displayed only to users with appropriate administrative privileges.

---

## 🏆 Certificates

Certificate generation is intentionally not implemented in the initial version.

The Certificate section currently displays:

> **Coming Soon**

Future versions may support certificate generation and downloads.

---

# 🏗️ Technology Stack

## Mobile Application

* **Flutter**
* **Dart**
* **Riverpod** – State management
* **GoRouter** – Navigation
* **Firebase Authentication** – Phone number + OTP authentication
* **Mobile Scanner** – QR code scanning

## Backend

* **Node.js**
* **Express.js**
* **MongoDB**
* **Mongoose**
* **JWT Authentication**
* **Firebase Admin SDK**

---

# 📐 Architecture

UniPulse follows a feature-based architecture designed to keep the application modular and maintainable.

The project is divided into:

```text
UniPulse/
│
├── apps/
│   │
│   ├── mobile/
│   │   └── Flutter application
│   │
│   └── backend/
│       └── Node.js / Express API
│
└── README.md
```

The Flutter application uses separation between:

```text
Presentation
    ↓
Providers / State Management
    ↓
API / Data Layer
    ↓
Backend
    ↓
MongoDB
```

Existing APIs, providers, models, authentication and navigation are reused across features rather than duplicating business logic.

---

# 🔐 Authentication

UniPulse uses phone-based authentication.

The authentication flow is:

```text
User enters phone number
        ↓
Firebase OTP verification
        ↓
Firebase ID Token
        ↓
UniPulse Backend
        ↓
Token verification
        ↓
User lookup / creation
        ↓
JWT issued
        ↓
Authenticated application session
```

User roles are retrieved from the backend and used for role-based access control throughout the application.

---

# 🚀 Getting Started

## Prerequisites

Make sure the following are installed:

* Flutter SDK
* Dart SDK
* Node.js
* npm
* MongoDB
* Firebase project
* Android Studio / VS Code

---

## Clone the Repository

```bash
git clone <YOUR_REPOSITORY_URL>
cd UniPulse
```

---

# 📱 Running the Flutter Application

Navigate to the mobile application:

```bash
cd apps/mobile
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

To check the Flutter project:

```bash
flutter analyze
```

---

# 🖥️ Running the Backend

Navigate to the backend:

```bash
cd apps/backend
```

Install dependencies:

```bash
npm install
```

Create your environment configuration based on the project's environment requirements.

Then start the backend:

```bash
npm run dev
```

The backend provides the APIs used by the Flutter application.

---

# 🗄️ Database

UniPulse uses **MongoDB** as its primary database.

The backend uses Mongoose for database interaction.

The database is intended to store application data such as:

* Users
* Colleges
* Events
* Registrations
* Announcements
* Notifications
* Administrative roles and permissions

> Configure your MongoDB connection through the backend environment configuration. Do not commit database credentials to GitHub.

---

# 🔑 Environment Variables

Sensitive configuration should be stored in environment variables rather than committed to the repository.

Typical backend configuration includes:

```env
MONGODB_URI=
JWT_ACCESS_SECRET=
JWT_REFRESH_SECRET=
JWT_ACCESS_EXPIRY=
JWT_REFRESH_EXPIRY=
```

Firebase configuration should also be provided through the appropriate Firebase configuration files/environment setup.

**Never commit private keys, passwords, API secrets, or production credentials to GitHub.**

---

# 📂 Main Project Areas

```text
apps/
├── mobile/
│   └── lib/
│       ├── core/
│       ├── features/
│       │   ├── admin/
│       │   ├── auth/
│       │   ├── events/
│       │   ├── qr_scanner/
│       │   ├── notifications/
│       │   ├── announcements/
│       │   └── profile/
│       └── routing/
│
└── backend/
    └── src/
        ├── modules/
        │   ├── auth/
        │   ├── users/
        │   ├── events/
        │   ├── admin/
        │   ├── announcements/
        │   └── notifications/
        └── shared/
```

> Exact folders may evolve as development continues.

---

# 🧪 Testing & Verification

Before submitting changes, the project should be checked using:

```bash
flutter analyze
```

Backend tests, where available, should also be executed.

Important functionality to verify includes:

* Authentication
* Navigation
* Event loading
* Event registration
* Calendar
* QR scanning
* Admin access control
* Event management
* Announcements
* Notifications

---

# 🛡️ Security

UniPulse uses several layers of security:

* Firebase phone authentication
* Backend Firebase token verification
* JWT access tokens
* JWT refresh tokens
* Role-based access control
* Protected administrative routes
* Server-side user verification

Administrative permissions should always be validated on the backend and not only hidden in the Flutter UI.

---

# 🗺️ Development Roadmap

### Module 1 — Event Calendar & Calendar Export

* [x] Dedicated Event Calendar
* [x] Monthly event view
* [x] Date-based event filtering
* [x] Event navigation
* [x] Calendar export support

### Module 2 — QR Scanner

* [x] Student QR scanner
* [x] Event QR detection
* [x] Event ID extraction
* [x] Existing Event API integration
* [x] Event Detail navigation
* [x] Duplicate scan prevention
* [x] QR error handling

### Module 3 — Admin Panel

* [x] Admin dashboard foundation
* [x] Role-based Admin Panel access
* [x] Event management foundation
* [x] Admin functionality
* [x] Super Admin functionality
* [x] Multi-admin management foundation

### Future Modules

* [ ] Complete production notification/reminder system
* [ ] Advanced multi-type QR functionality
* [ ] Certificate generation
* [ ] Advanced admin analytics
* [ ] Additional profile customization
* [ ] More application settings
* [ ] Production deployment
* [ ] Further security hardening

---

# 🎯 Project Goal

The goal of UniPulse is to simplify college event management by bringing everything into one application.

Instead of students having to search through posters, WhatsApp groups, Instagram pages, spreadsheets, and different registration links, UniPulse provides a centralized platform where they can:

```text
Discover Events
      ↓
View Details
      ↓
Scan QR / Register
      ↓
Receive Updates
      ↓
Attend Events
```

For organizers and administrators:

```text
Create Event
      ↓
Publish Event
      ↓
Manage Registrations
      ↓
Send Updates
      ↓
Manage Event
```

UniPulse aims to make college events easier to discover, easier to manage, and easier to participate in.

---

# 🤝 Contributing

Contributions and suggestions are welcome.

Before making changes:

1. Understand the existing architecture.
2. Reuse existing services and components.
3. Avoid duplicating APIs or business logic.
4. Keep the existing UI design language.
5. Test your changes.
6. Run `flutter analyze`.
7. Make sure existing functionality is not broken.

---

# 📄 License

This project is currently developed as a college/project application.

Add the appropriate license here if the project is later released as open source.

---

## ⭐ UniPulse

**Discover. Register. Participate.**

One platform for every college event.
