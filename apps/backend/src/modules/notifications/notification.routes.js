import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import {
  createNotification,
  getNotificationHistory,
  getMyNotifications,
  readNotification,
  readAllNotifications,
  removeMyNotification,
} from './notification.controller.js';

export const notificationRouter = Router();

notificationRouter.use(authenticate);

notificationRouter.get('/me', getMyNotifications);
notificationRouter.patch('/:recipientId/read', readNotification);
notificationRouter.post('/read-all', readAllNotifications);
notificationRouter.delete('/:recipientId', removeMyNotification);

notificationRouter.post('/', requirePermission(Permissions.SEND_NOTIFICATIONS), createNotification);
notificationRouter.get(
  '/history',
  requirePermission(Permissions.SEND_NOTIFICATIONS),
  getNotificationHistory
);
