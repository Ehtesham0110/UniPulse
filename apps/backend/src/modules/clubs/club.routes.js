import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import { asyncHandler } from '../../shared/utils/async-handler.js';
import { Club } from './club.model.js';

export const clubRouter = Router();

clubRouter.use(authenticate);

clubRouter.get('/', asyncHandler(async (req, res) => {
  const clubs = await Club.find({ collegeId: req.collegeId, status: 'Active' }).sort({ name: 1 });
  res.json({ success: true, data: clubs });
}));

clubRouter.post('/', requirePermission(Permissions.MANAGE_EVENTS), asyncHandler(async (req, res) => {
  const club = await Club.create({ ...req.body, collegeId: req.collegeId });
  res.status(201).json({ success: true, data: club });
}));

