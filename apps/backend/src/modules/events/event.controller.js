import { asyncHandler } from '../../shared/utils/async-handler.js';
import { Event, EventLifecycle } from './event.model.js';
import { Club } from '../clubs/club.model.js';
import { ApiError } from '../../shared/errors/api-error.js';
import { Permissions, roleHasPermission } from '../../shared/utils/roles.js';

const EVENT_CATEGORIES = ['Tech', 'Non Tech'];
const EVENT_TYPES = ['Individual', 'Team'];

// Lifecycle states a student/general user is allowed to browse. Draft,
// Pending Approval, and Cancelled events are only visible to their
// organizer/admin so half-finished or withdrawn events don't leak into
// student-facing listings.
const PUBLIC_LIFECYCLES = [
  EventLifecycle.PUBLISHED,
  EventLifecycle.REGISTRATION_OPEN,
  EventLifecycle.REGISTRATION_CLOSED,
  EventLifecycle.LIVE,
  EventLifecycle.COMPLETED,
  EventLifecycle.ARCHIVED,
];

function slugify(value) {
  return value.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
}

function uniqueSlug(title) {
  // A plain slugify(title) collides whenever two events share a title
  // (there's a unique index on collegeId+slug), which previously would
  // have crashed with a raw MongoDB E11000 error instead of a clean 4xx.
  // Timestamp alone can still collide for two creates in the same
  // millisecond, so a short random suffix is added too.
  const random = Math.random().toString(36).slice(2, 8);
  return `${slugify(title)}-${Date.now().toString(36)}-${random}`;
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function canSeeAllLifecycles(user) {
  return (
    roleHasPermission(user.role, Permissions.MANAGE_EVENTS) ||
    roleHasPermission(user.role, Permissions.CREATE_EVENT)
  );
}

function canManageEvent(user, event) {
  if (roleHasPermission(user.role, Permissions.MANAGE_EVENTS)) return true;
  if (!roleHasPermission(user.role, Permissions.EDIT_ASSIGNED_EVENT)) return false;
  const isCreator = event.createdBy?.toString() === user._id.toString();
  const isAssigned = (event.assignedOrganizerIds || []).some(
    (id) => id.toString() === user._id.toString()
  );
  return isCreator || isAssigned;
}

/**
 * Validates an event create/update payload and returns a list of
 * human-readable error messages (empty if valid). When `partial` is true
 * (updates), only fields that are present are validated — required-field
 * checks are skipped.
 */
function validateEventPayload(body, { partial = false } = {}) {
  const errors = [];
  const isMissing = (value) => value === undefined || value === null || value === '';

  if (!partial) {
    if (isMissing(body.title)) errors.push('Title is required');
    if (isMissing(body.description)) errors.push('Description is required');
    if (isMissing(body.venue)) errors.push('Venue is required');
    if (isMissing(body.clubId)) errors.push('clubId is required');
    if (isMissing(body.eventDate)) errors.push('Event date is required');
    if (isMissing(body.eventType)) errors.push('Event type is required');
    if (isMissing(body.category)) errors.push('Category is required');
  }

  if (!isMissing(body.category) && !EVENT_CATEGORIES.includes(body.category)) {
    errors.push(`Category must be one of: ${EVENT_CATEGORIES.join(', ')}`);
  }
  if (!isMissing(body.eventType) && !EVENT_TYPES.includes(body.eventType)) {
    errors.push(`Event type must be one of: ${EVENT_TYPES.join(', ')}`);
  }
  if (!isMissing(body.eventDate) && Number.isNaN(Date.parse(body.eventDate))) {
    errors.push('Event date is not a valid date');
  }

  const teamMin = body.teamMin ?? 1;
  const teamMax = body.teamMax ?? 1;
  if (body.eventType === 'Team' || (partial && (body.teamMin !== undefined || body.teamMax !== undefined))) {
    if (teamMin < 1) errors.push('teamMin must be at least 1');
    if (teamMax < teamMin) errors.push('teamMax must be greater than or equal to teamMin');
  }

  if (body.paid === true && !(Number(body.price) > 0)) {
    errors.push('price must be greater than 0 for paid events');
  }
  if (
    body.maximumParticipants !== undefined &&
    body.maximumParticipants !== null &&
    Number(body.maximumParticipants) < 1
  ) {
    errors.push('maximumParticipants must be at least 1');
  }

  return errors;
}

function serializeEvent(event, bookmarkedEventIds) {
  const plain = typeof event.toObject === 'function' ? event.toObject() : event;
  return { ...plain, isBookmarked: bookmarkedEventIds.has(plain._id.toString()) };
}

function bookmarkSetFor(user) {
  return new Set((user.bookmarks || []).map((id) => id.toString()));
}

export const listEvents = asyncHandler(async (req, res) => {
  const { category, lifecycle, clubId, search, bookmarked, startDate, endDate, page = 1, limit = 20 } = req.query;
  const filter = { collegeId: req.collegeId };

  if (category) {
    if (!EVENT_CATEGORIES.includes(category)) {
      throw new ApiError(422, `category must be one of: ${EVENT_CATEGORIES.join(', ')}`);
    }
    filter.category = category;
  }
  if (clubId) filter.clubId = clubId;

  if (lifecycle) {
    filter.lifecycle = lifecycle;
  } else if (!canSeeAllLifecycles(req.user)) {
    filter.lifecycle = { $in: PUBLIC_LIFECYCLES };
  }

  if (search && search.trim()) {
    const regex = new RegExp(escapeRegex(search.trim()), 'i');
    filter.$or = [{ title: regex }, { description: regex }];
  }

  if (startDate || endDate) {
    filter.eventDate = {};
    if (startDate) {
      const parsedStart = new Date(startDate);
      if (!Number.isNaN(parsedStart.getTime())) {
        filter.eventDate.$gte = parsedStart;
      }
    }
    if (endDate) {
      const parsedEnd = new Date(endDate);
      if (!Number.isNaN(parsedEnd.getTime())) {
        filter.eventDate.$lte = parsedEnd;
      }
    }
  }

  const pageNum = Math.max(1, Number(page) || 1);
  const limitNum = Math.min(100, Math.max(1, Number(limit) || 20));

  if (bookmarked === 'true') {
    filter._id = { $in: req.user.bookmarks || [] };
  }

  const events = await Event.find(filter)
    .sort({ eventDate: 1 })
    .skip((pageNum - 1) * limitNum)
    .limit(limitNum);

  const bookmarkedIds = bookmarkSetFor(req.user);
  res.json({ success: true, data: events.map((event) => serializeEvent(event, bookmarkedIds)) });
});

export const getEvent = asyncHandler(async (req, res) => {
  const event = await Event.findOne({ _id: req.params.eventId, collegeId: req.collegeId });
  if (!event) throw new ApiError(404, 'Event not found');

  const isRestricted = !PUBLIC_LIFECYCLES.includes(event.lifecycle);
  if (isRestricted && !canManageEvent(req.user, event) && !canSeeAllLifecycles(req.user)) {
    // Hide existence of draft/pending/cancelled events from students rather
    // than leaking a 403 (which would confirm the event exists).
    throw new ApiError(404, 'Event not found');
  }

  res.json({ success: true, data: serializeEvent(event, bookmarkSetFor(req.user)) });
});

export const createEvent = asyncHandler(async (req, res) => {
  const errors = validateEventPayload(req.body);
  if (errors.length) throw new ApiError(422, errors[0], { errors });

  const club = await Club.findOne({ _id: req.body.clubId, collegeId: req.collegeId });
  if (!club) throw new ApiError(422, 'clubId does not reference a valid club for your college');

  const lifecycle =
    req.body.requiresApproval === false ? EventLifecycle.DRAFT : EventLifecycle.PENDING_APPROVAL;

  try {
    const event = await Event.create({
      ...req.body,
      collegeId: req.collegeId,
      createdBy: req.user._id,
      slug: uniqueSlug(req.body.title),
      lifecycle,
      approval: {
        required: req.body.requiresApproval !== false,
        submittedBy: req.user._id,
        submittedAt: new Date(),
        decision: lifecycle === EventLifecycle.PENDING_APPROVAL ? 'Pending' : undefined,
      },
    });
    res.status(201).json({ success: true, data: event });
  } catch (error) {
    if (error.name === 'ValidationError') {
      throw new ApiError(422, Object.values(error.errors)[0]?.message ?? 'Invalid event data');
    }
    throw error;
  }
});

export const updateEvent = asyncHandler(async (req, res) => {
  const event = await Event.findOne({ _id: req.params.eventId, collegeId: req.collegeId });
  if (!event) throw new ApiError(404, 'Event not found');
  if (!canManageEvent(req.user, event)) {
    throw new ApiError(403, 'You do not have permission to edit this event');
  }

  const errors = validateEventPayload(req.body, { partial: true });
  if (errors.length) throw new ApiError(422, errors[0], { errors });

  if (req.body.clubId) {
    const club = await Club.findOne({ _id: req.body.clubId, collegeId: req.collegeId });
    if (!club) throw new ApiError(422, 'clubId does not reference a valid club for your college');
  }

  // Fields that must never be overwritten by an arbitrary update payload.
  const protectedFields = [
    'collegeId', 'createdBy', 'currentParticipants', 'approval', 'slug', '_id',
  ];
  const updates = { ...req.body };
  for (const field of protectedFields) delete updates[field];

  if (updates.title && updates.title !== event.title) {
    updates.slug = uniqueSlug(updates.title);
  }

  try {
    Object.assign(event, updates);
    await event.save();
    res.json({ success: true, data: event });
  } catch (error) {
    if (error.name === 'ValidationError') {
      throw new ApiError(422, Object.values(error.errors)[0]?.message ?? 'Invalid event data');
    }
    throw error;
  }
});

export const deleteEvent = asyncHandler(async (req, res) => {
  const event = await Event.findOne({ _id: req.params.eventId, collegeId: req.collegeId });
  if (!event) throw new ApiError(404, 'Event not found');

  if (event.currentParticipants > 0) {
    throw new ApiError(
      409,
      'This event already has registrations and cannot be deleted. Cancel it instead.'
    );
  }

  await Event.deleteOne({ _id: event._id });
  res.json({ success: true, data: { deleted: true } });
});

export const approveEvent = asyncHandler(async (req, res) => {
  const event = await Event.findOne({ _id: req.params.eventId, collegeId: req.collegeId });
  if (!event) throw new ApiError(404, 'Event not found');
  event.lifecycle = EventLifecycle.PUBLISHED;
  event.approval = {
    ...event.approval,
    reviewedBy: req.user._id,
    reviewedAt: new Date(),
    decision: 'Approved',
    notes: req.body.notes,
  };
  await event.save();
  res.json({ success: true, data: event });
});

/**
 * Toggles whether the current user has bookmarked this event. Bookmarks
 * are stored on the User document (`user.bookmarks: [Event]`), which
 * already existed in the schema before this milestone but had no
 * endpoints wired to it.
 */
export const toggleBookmark = asyncHandler(async (req, res) => {
  const event = await Event.findOne({ _id: req.params.eventId, collegeId: req.collegeId });
  if (!event) throw new ApiError(404, 'Event not found');

  const eventIdStr = event._id.toString();
  const alreadyBookmarked = (req.user.bookmarks || []).some((id) => id.toString() === eventIdStr);

  if (alreadyBookmarked) {
    req.user.bookmarks = req.user.bookmarks.filter((id) => id.toString() !== eventIdStr);
  } else {
    req.user.bookmarks = [...(req.user.bookmarks || []), event._id];
  }
  await req.user.save();

  res.json({ success: true, data: { eventId: event._id, isBookmarked: !alreadyBookmarked } });
});
