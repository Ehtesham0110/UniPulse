import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import {
  approveEvent,
  createEvent,
  deleteEvent,
  getEvent,
  listEvents,
  toggleBookmark,
  updateEvent,
} from './event.controller.js';

export const eventRouter = Router();

eventRouter.use(authenticate);

eventRouter.get('/', listEvents);
eventRouter.get('/:eventId', getEvent);
eventRouter.post('/', requirePermission(Permissions.CREATE_EVENT), createEvent);
eventRouter.patch('/:eventId', updateEvent);
eventRouter.delete('/:eventId', requirePermission(Permissions.MANAGE_EVENTS), deleteEvent);
eventRouter.post('/:eventId/approve', requirePermission(Permissions.MANAGE_EVENTS), approveEvent);
eventRouter.post('/:eventId/bookmark', toggleBookmark);
