# UniPulse API Design

All endpoints are scoped by the authenticated user's `collegeId` unless explicitly marked as system-level Super Admin endpoints.

## Auth

- `POST /api/auth/firebase-login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`

## College & Branding

- `GET /api/colleges/current`
- `PATCH /api/colleges/:collegeId/branding`
- `GET /api/settings`
- `PATCH /api/settings`

## Users

- `GET /api/users/me`
- `PATCH /api/users/me`
- `GET /api/users`
- `PATCH /api/users/:userId/role`
- `PATCH /api/users/:userId/suspend`

## Clubs

- `GET /api/clubs`
- `POST /api/clubs`
- `PATCH /api/clubs/:clubId`
- `DELETE /api/clubs/:clubId`

## Events

- `GET /api/events`
- `GET /api/events/:eventId`
- `POST /api/events`
- `PATCH /api/events/:eventId`
- `POST /api/events/:eventId/submit-for-approval`
- `POST /api/events/:eventId/approve`
- `POST /api/events/:eventId/reject`
- `POST /api/events/:eventId/publish`
- `POST /api/events/:eventId/cancel`
- `POST /api/events/:eventId/bookmark`
- `DELETE /api/events/:eventId/bookmark`

## Registrations & Teams

- `POST /api/teams`
- `PATCH /api/teams/:teamId/members`
- `POST /api/registrations`
- `GET /api/registrations/me`
- `GET /api/registrations/:registrationId`
- `GET /api/events/:eventId/participants`

## Payments

- `POST /api/payments/razorpay/order`
- `POST /api/payments/razorpay/verify`
- `GET /api/payments/:paymentId`

## Attendance & QR

- `POST /api/attendance/validate-qr`
- `POST /api/attendance/manual-code`
- `POST /api/attendance/:attendanceId/check-out`

## Certificates

- `GET /api/certificates`
- `GET /api/certificates/:certificateId/preview`
- `GET /api/certificates/:certificateId/download`
- `POST /api/admin/certificate-templates`
- `POST /api/admin/certificates/generate`
- `POST /api/admin/certificates/upload`
- `POST /api/admin/certificates/:certificateId/issue`

## Notifications

- `POST /api/notifications/send`
- `GET /api/notifications`
- `PATCH /api/notifications/:notificationId/read`

## Analytics

- `GET /api/analytics/overview`
- `GET /api/analytics/events/popular`
- `GET /api/analytics/participation/branch`
- `GET /api/analytics/participation/year`
- `GET /api/analytics/trends/registrations`
- `GET /api/analytics/trends/attendance`

