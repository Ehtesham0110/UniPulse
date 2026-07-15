import { ApiError } from '../../shared/errors/api-error.js';
import { sendPushNotification } from '../../config/firebase-messaging.js';
import { Notification, NotificationRecipient } from './notification.model.js';
import { User } from '../users/user.model.js';
import { Club } from '../clubs/club.model.js';
import { Event } from '../events/event.model.js';
import { Registration } from '../registrations/registration.model.js';

const AUDIENCE_TYPES = [
  'College',
  'Branch',
  'Year',
  'Club',
  'Event Participants',
  'Individual Student',
];

/**
 * Resolves an audience descriptor into the list of student user ids it
 * targets. Every branch validates its own required field(s) and throws a
 * clear 422 if the referenced club/event/user doesn't exist for this
 * college.
 *
 * All broadcast audience types (College/Branch/Year/Club/Event
 * Participants) target Students specifically — Organizers/Admins aren't
 * students and don't have `branch`/`year`, so including them would be
 * meaningless for 3 of the 5 types and inconsistent for the other 2.
 * "Individual Student" can target any single user by id regardless of role.
 */
export async function resolveAudienceUserIds({ collegeId, audience }) {
  if (!audience || !AUDIENCE_TYPES.includes(audience.type)) {
    throw new ApiError(422, `audience.type must be one of: ${AUDIENCE_TYPES.join(', ')}`);
  }

  switch (audience.type) {
    case 'College': {
      return User.find({ collegeId, role: 'Student', status: 'Active' }).distinct('_id');
    }

    case 'Branch': {
      if (!audience.branch) throw new ApiError(422, 'audience.branch is required');
      return User.find({
        collegeId,
        role: 'Student',
        status: 'Active',
        branch: audience.branch,
      }).distinct('_id');
    }

    case 'Year': {
      if (!audience.year) throw new ApiError(422, 'audience.year is required');
      return User.find({
        collegeId,
        role: 'Student',
        status: 'Active',
        year: audience.year,
      }).distinct('_id');
    }

    case 'Club': {
      if (!audience.clubId) throw new ApiError(422, 'audience.clubId is required');
      const club = await Club.findOne({ _id: audience.clubId, collegeId });
      if (!club) throw new ApiError(422, 'audience.clubId does not reference a valid club');

      // No club-membership list exists in this schema — a club's
      // "audience" is approximated as everyone who has registered for at
      // least one of its (non-cancelled) events. Documented scope choice.
      const eventIds = await Event.find({ collegeId, clubId: club._id }).distinct('_id');
      if (eventIds.length === 0) return [];
      return Registration.find({
        collegeId,
        eventId: { $in: eventIds },
        status: { $ne: 'Cancelled' },
      }).distinct('studentId');
    }

    case 'Event Participants': {
      if (!audience.eventId) throw new ApiError(422, 'audience.eventId is required');
      const event = await Event.findOne({ _id: audience.eventId, collegeId });
      if (!event) throw new ApiError(422, 'audience.eventId does not reference a valid event');
      return Registration.find({
        collegeId,
        eventId: event._id,
        status: { $ne: 'Cancelled' },
      }).distinct('studentId');
    }

    case 'Individual Student': {
      if (!audience.userId) throw new ApiError(422, 'audience.userId is required');
      const student = await User.findOne({ _id: audience.userId, collegeId });
      if (!student) throw new ApiError(422, 'audience.userId does not reference a valid user');
      return [student._id];
    }

    default:
      // Unreachable given the AUDIENCE_TYPES check above.
      throw new ApiError(422, 'Unsupported audience type');
  }
}

/**
 * Sends a notification: resolves its audience, creates the broadcast
 * record and one delivery/read-tracking row per recipient, and makes a
 * best-effort push attempt via FCM (or the mock provider — see
 * firebase-messaging.js). Push delivery success/failure never blocks or
 * fails this call; the in-app inbox rows are the primary delivery
 * mechanism.
 */
export async function sendNotification({ collegeId, title, body, imageUrl, audience, sentBy }) {
  if (!title?.trim()) throw new ApiError(400, 'title is required');
  if (!body?.trim()) throw new ApiError(400, 'body is required');

  const userIds = await resolveAudienceUserIds({ collegeId, audience });
  if (userIds.length === 0) {
    throw new ApiError(422, 'No recipients matched this audience. Nothing was sent.', {
      reason: 'NO_RECIPIENTS',
    });
  }

  const notification = await Notification.create({
    collegeId,
    title: title.trim(),
    body: body.trim(),
    imageUrl,
    audience,
    sentBy,
    status: 'Queued',
    recipientCount: userIds.length,
  });

  await NotificationRecipient.insertMany(
    userIds.map((userId) => ({
      collegeId,
      notificationId: notification._id,
      userId,
      isRead: false,
      readAt: null,
      deletedAt: null,
    })),
    { ordered: false }
  );

  const recipients = await User.find({ _id: { $in: userIds } }).select('fcmTokens');
  const tokens = recipients.flatMap((u) => u.fcmTokens ?? []);
  const push = await sendPushNotification({ tokens, title: notification.title, body: notification.body });

  notification.status = 'Sent';
  notification.sentAt = new Date();
  await notification.save();

  return { notification, recipientCount: userIds.length, push };
}

export async function listNotificationHistory({ collegeId, page = 1, limit = 20 }) {
  const pageNum = Math.max(1, Number(page) || 1);
  const limitNum = Math.min(100, Math.max(1, Number(limit) || 20));

  const [items, total] = await Promise.all([
    Notification.find({ collegeId })
      .sort({ createdAt: -1 })
      .skip((pageNum - 1) * limitNum)
      .limit(limitNum),
    Notification.countDocuments({ collegeId }),
  ]);

  return { items, page: pageNum, limit: limitNum, total };
}

export async function listMyNotifications({ collegeId, userId, page = 1, limit = 20 }) {
  const pageNum = Math.max(1, Number(page) || 1);
  const limitNum = Math.min(100, Math.max(1, Number(limit) || 20));
  const filter = { collegeId, userId, deletedAt: null };

  const [items, total, unreadCount] = await Promise.all([
    NotificationRecipient.find(filter)
      .populate('notificationId', 'title body imageUrl audience sentAt')
      .sort({ createdAt: -1 })
      .skip((pageNum - 1) * limitNum)
      .limit(limitNum),
    NotificationRecipient.countDocuments(filter),
    NotificationRecipient.countDocuments({ ...filter, isRead: false }),
  ]);

  return { items, page: pageNum, limit: limitNum, total, unreadCount };
}

async function findOwnRecipient({ collegeId, userId, recipientId }) {
  const recipient = await NotificationRecipient.findOne({
    _id: recipientId,
    collegeId,
    userId,
    deletedAt: null,
  });
  if (!recipient) throw new ApiError(404, 'Notification not found');
  return recipient;
}

export async function markNotificationRead({ collegeId, userId, recipientId }) {
  const recipient = await findOwnRecipient({ collegeId, userId, recipientId });
  if (!recipient.isRead) {
    recipient.isRead = true;
    recipient.readAt = new Date();
    await recipient.save();
  }
  return recipient;
}

export async function markAllNotificationsRead({ collegeId, userId }) {
  const result = await NotificationRecipient.updateMany(
    { collegeId, userId, deletedAt: null, isRead: false },
    { $set: { isRead: true, readAt: new Date() } }
  );
  return { updatedCount: result.modifiedCount ?? 0 };
}

export async function deleteMyNotification({ collegeId, userId, recipientId }) {
  const recipient = await findOwnRecipient({ collegeId, userId, recipientId });
  recipient.deletedAt = new Date();
  await recipient.save();
  return recipient;
}
