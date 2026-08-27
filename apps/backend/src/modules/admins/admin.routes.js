import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import {
  listAdmins,
  inviteAdmin,
  updateAdminRole,
  removeAdmin,
} from './admin.controller.js';

export const adminRouter = Router();

adminRouter.use(authenticate);
adminRouter.use(requirePermission(Permissions.MANAGE_ADMINS));

adminRouter.get('/', listAdmins);
adminRouter.post('/invite', inviteAdmin);
adminRouter.patch('/:userId/role', updateAdminRole);
adminRouter.delete('/:userId', removeAdmin);
