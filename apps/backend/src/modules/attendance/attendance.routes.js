import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import { validateQr, checkIn, checkOut } from './attendance.controller.js';

export const attendanceRouter = Router();

attendanceRouter.use(authenticate);
attendanceRouter.use(requirePermission(Permissions.MARK_ATTENDANCE));

attendanceRouter.post('/validate', validateQr);
attendanceRouter.post('/check-in', checkIn);
attendanceRouter.post('/check-out', checkOut);
