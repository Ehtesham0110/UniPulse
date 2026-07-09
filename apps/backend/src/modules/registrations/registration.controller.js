import mongoose from 'mongoose';
import { asyncHandler } from '../../shared/utils/async-handler.js';
import { ApiError } from '../../shared/errors/api-error.js';
import { buildQrToken } from '../../shared/utils/qr-token.js';
import { Registration } from './registration.model.js';
import { Team, TeamMember } from '../teams/team.model.js';
import { Event, EventLifecycle } from '../events/event.model.js';

const OPEN_LIFECYCLES = new Set([EventLifecycle.REGISTRATION_OPEN]);

/**
 * Registers the current user for an event, as either an individual or as
 * the leader of a new team, depending on the event's `eventType`.
 *
 * Free events are confirmed immediately (with an atomic capacity check to
 * prevent overselling). Paid events are created in `Pending Payment` status
 * and do not consume a capacity slot until payment succeeds — Razorpay
 * integration for that step is a separate, later milestone (see
 * AI_HANDOVER.md).
 */
export const registerForEvent = asyncHandler(async (req, res) => {
  const { eventId, teamName, members } = req.body;
  if (!eventId) throw new ApiError(400, 'eventId is required');

  const event = await Event.findOne({ _id: eventId, collegeId: req.collegeId });
  if (!event) throw new ApiError(404, 'Event not found');

  if (!OPEN_LIFECYCLES.has(event.lifecycle)) {
    throw new ApiError(409, 'Registration is not currently open for this event');
  }
  if (event.registrationEnd && event.registrationEnd < new Date()) {
    throw new ApiError(409, 'The registration window for this event has closed');
  }

  const alreadyRegistered = await Registration.findOne({
    collegeId: req.collegeId,
    eventId,
    studentId: req.user._id,
    status: { $ne: 'Cancelled' },
  });
  if (alreadyRegistered) {
    throw new ApiError(409, 'You are already registered for this event');
  }

  let teamId;
  if (event.eventType === 'Team') {
    const teamMembers = Array.isArray(members) ? members : [];
    const totalSize = teamMembers.length + 1; // + the leader (current user)

    if (totalSize < event.teamMin || totalSize > event.teamMax) {
      throw new ApiError(
        422,
        `Team size must be between ${event.teamMin} and ${event.teamMax} members (including you). You provided ${totalSize}.`
      );
    }
    for (const member of teamMembers) {
      if (!member.fullName || !member.phone) {
        throw new ApiError(422, 'Each team member needs a fullName and phone');
      }
    }
    if (!teamName || !teamName.trim()) {
      throw new ApiError(422, 'teamName is required for team events');
    }

    const team = await Team.create({
      collegeId: req.collegeId,
      eventId,
      teamName: teamName.trim(),
      leaderId: req.user._id,
      status: 'Registered',
    });

    await TeamMember.create([
      {
        collegeId: req.collegeId,
        teamId: team._id,
        userId: req.user._id,
        fullName: req.user.fullName,
        phone: req.user.phone,
        rollNumber: req.user.rollNumber,
        role: 'Leader',
      },
      ...teamMembers.map((member) => ({
        collegeId: req.collegeId,
        teamId: team._id,
        fullName: member.fullName,
        phone: member.phone,
        rollNumber: member.rollNumber,
        role: 'Member',
      })),
    ]);

    teamId = team._id;
  }

  const registrationId = new mongoose.Types.ObjectId();
  const { tokenHash: qrTokenHash } = buildQrToken(registrationId);
  const status = event.paid ? 'Pending Payment' : 'Confirmed';

  if (!event.paid) {
    const capacityUpdatedEvent = await Event.findOneAndUpdate(
      {
        _id: event._id,
        collegeId: req.collegeId,
        $expr: {
          $or: [
            { $eq: ['$maximumParticipants', null] },
            { $lt: ['$currentParticipants', '$maximumParticipants'] },
          ],
        },
      },
      { $inc: { currentParticipants: 1 } },
      { new: true }
    );
    if (!capacityUpdatedEvent) {
      if (teamId) await Team.findByIdAndDelete(teamId);
      throw new ApiError(409, 'This event has reached its maximum number of participants');
    }
  }

  const registration = await Registration.create({
    _id: registrationId,
    collegeId: req.collegeId,
    eventId,
    studentId: req.user._id,
    teamId,
    qrTokenHash,
    status,
  });

  if (teamId) {
    await Team.findByIdAndUpdate(teamId, { registrationId: registration._id });
  }

  res.status(201).json({
    success: true,
    data: {
      registration,
      // The QR token is deterministic (HMAC of the registration id), so
      // it can always be regenerated later via GET /:registrationId/qr —
      // it doesn't need to be saved anywhere client-side.
      qrToken: buildQrToken(registration._id).token,
    },
  });
});

export const listMyRegistrations = asyncHandler(async (req, res) => {
  const registrations = await Registration.find({
    collegeId: req.collegeId,
    studentId: req.user._id,
  })
    .populate('eventId', 'title eventDate venue category media.thumbnailUrl lifecycle')
    .sort({ createdAt: -1 });

  res.json({ success: true, data: registrations });
});

/**
 * Returns the QR token for the current user's own registration, so the
 * Flutter app can render/re-render the QR code in "My Events" without
 * ever needing to cache the raw token itself. Only shown for
 * registrations that are actually checkable-in (Confirmed or Attended) —
 * a cancelled or still-unpaid registration has nothing to scan.
 */
export const getRegistrationQr = asyncHandler(async (req, res) => {
  const registration = await Registration.findOne({
    _id: req.params.registrationId,
    collegeId: req.collegeId,
    studentId: req.user._id,
  });
  if (!registration) throw new ApiError(404, 'Registration not found');

  if (!['Confirmed', 'Attended', 'Completed'].includes(registration.status)) {
    throw new ApiError(
      409,
      registration.status === 'Pending Payment'
        ? 'Complete payment to get your QR code'
        : 'This registration does not have a QR code',
      { reason: 'NO_QR_AVAILABLE' }
    );
  }

  res.json({
    success: true,
    data: { qrToken: buildQrToken(registration._id).token, registrationId: registration._id },
  });
});

export const listEventRegistrations = asyncHandler(async (req, res) => {
  const { eventId } = req.params;
  const event = await Event.findOne({ _id: eventId, collegeId: req.collegeId });
  if (!event) throw new ApiError(404, 'Event not found');

  const registrations = await Registration.find({ collegeId: req.collegeId, eventId })
    .populate('studentId', 'fullName phone rollNumber branch year')
    .populate('teamId', 'teamName')
    .sort({ createdAt: -1 });

  res.json({ success: true, data: registrations });
});

export const cancelRegistration = asyncHandler(async (req, res) => {
  const registration = await Registration.findOne({
    _id: req.params.registrationId,
    collegeId: req.collegeId,
    studentId: req.user._id,
  });
  if (!registration) throw new ApiError(404, 'Registration not found');
  if (registration.status === 'Cancelled') {
    throw new ApiError(409, 'This registration is already cancelled');
  }
  if (['Attended', 'Completed'].includes(registration.status)) {
    throw new ApiError(409, 'You cannot cancel a registration after the event has taken place');
  }

  const wasConfirmed = registration.status === 'Confirmed';
  registration.status = 'Cancelled';
  await registration.save();

  if (wasConfirmed) {
    await Event.findByIdAndUpdate(registration.eventId, { $inc: { currentParticipants: -1 } });
  }
  if (registration.teamId) {
    await Team.findByIdAndUpdate(registration.teamId, { status: 'Cancelled' });
  }

  res.json({ success: true, data: registration });
});
