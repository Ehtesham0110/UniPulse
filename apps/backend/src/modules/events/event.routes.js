import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import { approveEvent, createEvent, getEvent, listEvents } from './event.controller.js';

export const eventRouter = Router();

eventRouter.use(authenticate);
eventRouter.get('/', listEvents);
eventRouter.get('/:eventId', getEvent);
eventRouter.post('/', requirePermission(Permissions.CREATE_EVENT), createEvent);
eventRouter.post('/:eventId/approve', requirePermission(Permissions.MANAGE_EVENTS), approveEvent);

