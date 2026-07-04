import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import { College } from './college.model.js';
import { asyncHandler } from '../../shared/utils/async-handler.js';

export const collegeRouter = Router();

collegeRouter.get('/current', authenticate, asyncHandler(async (req, res) => {
  const college = await College.findById(req.collegeId);
  res.json({ success: true, data: college });
}));

collegeRouter.patch(
  '/:collegeId/branding',
  authenticate,
  requirePermission(Permissions.MANAGE_COLLEGE_SETTINGS),
  asyncHandler(async (req, res) => {
    const college = await College.findOneAndUpdate(
      { _id: req.params.collegeId },
      { $set: { branding: req.body.branding } },
      { new: true }
    );
    res.json({ success: true, data: college });
  })
);

