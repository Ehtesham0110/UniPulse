import { asyncHandler } from '../../shared/utils/async-handler.js';
import { ApiError } from '../../shared/errors/api-error.js';
import { Roles } from '../../shared/utils/roles.js';
import { User } from '../users/user.model.js';

export const listAdmins = asyncHandler(async (req, res) => {
  const admins = await User.find({
    collegeId: req.collegeId,
    role: { $in: [Roles.ADMIN, Roles.SUPER_ADMIN, Roles.ORGANIZER] },
  }).sort({ createdAt: -1 });

  res.json({ success: true, data: admins });
});

export const inviteAdmin = asyncHandler(async (req, res) => {
  const { phone, fullName, role } = req.body;
  if (!phone || !phone.trim()) {
    throw new ApiError(400, 'Mobile number is required');
  }

  const cleanPhone = phone.trim();
  const targetRole = role || Roles.ADMIN;

  if (![Roles.ADMIN, Roles.SUPER_ADMIN, Roles.ORGANIZER].includes(targetRole)) {
    throw new ApiError(400, 'Invalid role for admin management');
  }

  let user = await User.findOne({ collegeId: req.collegeId, phone: cleanPhone });
  if (user) {
    user.role = targetRole;
    if (fullName && fullName.trim()) {
      user.fullName = fullName.trim();
    }
    await user.save();
  } else {
    user = await User.create({
      collegeId: req.collegeId,
      phone: cleanPhone,
      fullName: fullName?.trim() || 'New Admin',
      rollNumber: 'ADMIN',
      branch: 'ADMIN',
      year: 1,
      role: targetRole,
      status: 'Active',
    });
  }

  res.status(201).json({ success: true, data: user });
});

export const updateAdminRole = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const { role } = req.body;

  if (![Roles.STUDENT, Roles.ORGANIZER, Roles.ADMIN, Roles.SUPER_ADMIN].includes(role)) {
    throw new ApiError(400, 'Invalid role');
  }

  const user = await User.findOne({ _id: userId, collegeId: req.collegeId });
  if (!user) {
    throw new ApiError(404, 'Admin user not found');
  }

  if (user._id.toString() === req.user._id.toString()) {
    throw new ApiError(400, 'You cannot modify your own role');
  }

  user.role = role;
  await user.save();

  res.json({ success: true, data: user });
});

export const removeAdmin = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const user = await User.findOne({ _id: userId, collegeId: req.collegeId });
  if (!user) {
    throw new ApiError(404, 'Admin user not found');
  }

  if (user._id.toString() === req.user._id.toString()) {
    throw new ApiError(400, 'You cannot remove yourself');
  }

  user.role = Roles.STUDENT;
  await user.save();

  res.json({ success: true, data: { removed: true, user } });
});
