import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import {
  registerForEvent,
  listMyRegistrations,
  getRegistrationQr,
  listEventRegistrations,
  cancelRegistration,
} from './registration.controller.js';

export const registrationRouter = Router();

registrationRouter.use(authenticate);

registrationRouter.post('/', registerForEvent);
registrationRouter.get('/me', listMyRegistrations);
registrationRouter.get('/:registrationId/qr', getRegistrationQr);
registrationRouter.get(
  '/event/:eventId',
  requirePermission(Permissions.VIEW_PARTICIPANTS),
  listEventRegistrations
);
registrationRouter.patch('/:registrationId/cancel', cancelRegistration);
