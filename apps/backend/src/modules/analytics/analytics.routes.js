import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import { asyncHandler } from '../../shared/utils/async-handler.js';
import { User } from '../users/user.model.js';
import { Payment } from '../payments/payment.model.js';
import { Attendance } from '../attendance/attendance.model.js';

export const analyticsRouter = Router();

analyticsRouter.use(authenticate, requirePermission(Permissions.VIEW_ANALYTICS));

analyticsRouter.get('/overview', asyncHandler(async (req, res) => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const [totalStudents, activeUsers, todaysCheckIns, revenue] = await Promise.all([
    User.countDocuments({ collegeId: req.collegeId, role: 'Student' }),
    User.countDocuments({ collegeId: req.collegeId, lastActiveAt: { $gte: today } }),
    Attendance.countDocuments({ collegeId: req.collegeId, checkedIn: true, checkInTime: { $gte: today } }),
    Payment.aggregate([
      { $match: { collegeId: req.collegeId, status: 'Paid' } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),
  ]);

  res.json({
    success: true,
    data: {
      totalStudents,
      activeUsers,
      todaysCheckIns,
      revenue: revenue[0]?.total ?? 0,
    },
  });
}));

