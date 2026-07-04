import { asyncHandler } from '../../shared/utils/async-handler.js';
import { Event, EventLifecycle } from './event.model.js';
import { ApiError } from '../../shared/errors/api-error.js';

function slugify(value) {
  return value.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
}

export const listEvents = asyncHandler(async (req, res) => {
  const { category, lifecycle, clubId, page = 1, limit = 20 } = req.query;
  const filter = { collegeId: req.collegeId };
  if (category) filter.category = category;
  if (lifecycle) filter.lifecycle = lifecycle;
  if (clubId) filter.clubId = clubId;

  const events = await Event.find(filter)
    .sort({ eventDate: 1 })
    .skip((Number(page) - 1) * Number(limit))
    .limit(Number(limit));

  res.json({ success: true, data: events });
});

export const getEvent = asyncHandler(async (req, res) => {
  const event = await Event.findOne({ _id: req.params.eventId, collegeId: req.collegeId });
  if (!event) throw new ApiError(404, 'Event not found');
  res.json({ success: true, data: event });
});

export const createEvent = asyncHandler(async (req, res) => {
  const lifecycle = req.body.requiresApproval === false ? EventLifecycle.DRAFT : EventLifecycle.PENDING_APPROVAL;
  const event = await Event.create({
    ...req.body,
    collegeId: req.collegeId,
    createdBy: req.user._id,
    slug: slugify(req.body.title),
    lifecycle,
    approval: {
      required: req.body.requiresApproval !== false,
      submittedBy: req.user._id,
      submittedAt: new Date(),
      decision: lifecycle === EventLifecycle.PENDING_APPROVAL ? 'Pending' : undefined,
    },
  });
  res.status(201).json({ success: true, data: event });
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

