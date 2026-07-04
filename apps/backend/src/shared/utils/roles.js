export const Roles = Object.freeze({
  STUDENT: 'Student',
  ORGANIZER: 'Organizer',
  ADMIN: 'Admin',
  SUPER_ADMIN: 'Super Admin',
});

export const Permissions = Object.freeze({
  REGISTER_EVENT: 'register:event',
  VIEW_CERTIFICATE: 'view:certificate',
  SCAN_QR: 'scan:qr',
  EDIT_SELF: 'edit:self',
  CREATE_EVENT: 'create:event',
  EDIT_ASSIGNED_EVENT: 'edit:assigned-event',
  VIEW_PARTICIPANTS: 'view:participants',
  MARK_ATTENDANCE: 'mark:attendance',
  MANAGE_EVENTS: 'manage:events',
  MANAGE_ORGANIZERS: 'manage:organizers',
  SEND_NOTIFICATIONS: 'send:notifications',
  ISSUE_CERTIFICATES: 'issue:certificates',
  VIEW_ANALYTICS: 'view:analytics',
  MANAGE_ADMINS: 'manage:admins',
  MANAGE_COLLEGE_SETTINGS: 'manage:college-settings',
});

export const rolePermissions = {
  [Roles.STUDENT]: [
    Permissions.REGISTER_EVENT,
    Permissions.VIEW_CERTIFICATE,
    Permissions.SCAN_QR,
    Permissions.EDIT_SELF,
  ],
  [Roles.ORGANIZER]: [
    Permissions.CREATE_EVENT,
    Permissions.EDIT_ASSIGNED_EVENT,
    Permissions.VIEW_PARTICIPANTS,
    Permissions.MARK_ATTENDANCE,
  ],
  [Roles.ADMIN]: [
    Permissions.MANAGE_EVENTS,
    Permissions.MANAGE_ORGANIZERS,
    Permissions.SEND_NOTIFICATIONS,
    Permissions.ISSUE_CERTIFICATES,
    Permissions.VIEW_ANALYTICS,
  ],
  [Roles.SUPER_ADMIN]: Object.values(Permissions),
};

export function roleHasPermission(role, permission) {
  return rolePermissions[role]?.includes(permission) ?? false;
}

