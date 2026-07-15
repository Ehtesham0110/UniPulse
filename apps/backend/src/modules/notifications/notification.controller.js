import { asyncHandler } from '../../shared/utils/async-handler.js';
import {
  sendNotification,
  listNotificationHistory,
  listMyNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  deleteMyNotification,
} from './notification.service.js';

export const createNotification = asyncHandler(async (req, res) => {
  const { title, body, imageUrl, audience } = req.body;
  const result = await sendNotification({
    collegeId: req.collegeId,
    title,
    body,
    imageUrl,
    audience,
    sentBy: req.user._id,
  });
  res.status(201).json({ success: true, data: result });
});

export const getNotificationHistory = asyncHandler(async (req, res) => {
  const { page, limit } = req.query;
  const result = await listNotificationHistory({ collegeId: req.collegeId, page, limit });
  res.json({ success: true, data: result });
});

export const getMyNotifications = asyncHandler(async (req, res) => {
  const { page, limit } = req.query;
  const result = await listMyNotifications({
    collegeId: req.collegeId,
    userId: req.user._id,
    page,
    limit,
  });
  res.json({ success: true, data: result });
});

export const readNotification = asyncHandler(async (req, res) => {
  const recipient = await markNotificationRead({
    collegeId: req.collegeId,
    userId: req.user._id,
    recipientId: req.params.recipientId,
  });
  res.json({ success: true, data: recipient });
});

export const readAllNotifications = asyncHandler(async (req, res) => {
  const result = await markAllNotificationsRead({ collegeId: req.collegeId, userId: req.user._id });
  res.json({ success: true, data: result });
});

export const removeMyNotification = asyncHandler(async (req, res) => {
  await deleteMyNotification({
    collegeId: req.collegeId,
    userId: req.user._id,
    recipientId: req.params.recipientId,
  });
  res.json({ success: true, data: { deleted: true } });
});
