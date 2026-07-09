import { asyncHandler } from '../../shared/utils/async-handler.js';
import { ApiError } from '../../shared/errors/api-error.js';
import { extractRegistrationId, buildQrToken } from '../../shared/utils/qr-token.js';
import { Registration } from '../registrations/registration.model.js';
import { Event, EventLifecycle } from '../events/event.model.js';
import { User } from '../users/user.model.js';
import { Attendance } from './attendance.model.js';

const ENDED_LIFECYCLES = new Set([EventLifecycle.CANCELLED, EventLifecycle.ARCHIVED]);

/**
 * Resolves and validates a scanned QR token into its registration, event,
 * and student — shared by validate/check-in/check-out so the same rules
 * apply everywhere a QR is scanned. Throws an ApiError with a `reason`
 * code in `details` for every failure case, so the Flutter scanner can
 * show a specific message (invalid QR vs. cancelled vs. wrong event...)
 * instead of a generic error.
 */
async function resolveScannedRegistration({ qrToken, eventId, collegeId }) {
  const registrationId = extractRegistrationId(qrToken);
  if (!registrationId) {
    throw new ApiError(400, 'This QR code is not valid.', { reason: 'INVALID_QR' });
  }

  const registration = await Registration.findOne({ _id: registrationId, collegeId });
  if (!registration) {
    throw new ApiError(404, 'This QR code is not valid.', { reason: 'INVALID_QR' });
  }

  // Defense in depth: the HMAC signature already proves the token is
  // well-formed and untampered, but re-deriving and comparing against the
  // stored hash catches the (practically impossible) case of a token
  // that's validly signed for a registration id that was regenerated
  // with a different hash — e.g. data corruption.
  const { tokenHash } = buildQrToken(registration._id);
  if (tokenHash !== registration.qrTokenHash) {
    throw new ApiError(400, 'This QR code is not valid.', { reason: 'INVALID_QR' });
  }

  const event = await Event.findOne({ _id: registration.eventId, collegeId });
  if (!event) {
    throw new ApiError(404, 'The event for this QR code could not be found.', { reason: 'INVALID_QR' });
  }

  if (eventId && eventId !== registration.eventId.toString()) {
    throw new ApiError(409, 'This QR code is for a different event.', { reason: 'WRONG_EVENT' });
  }

  if (registration.status === 'Cancelled') {
    throw new ApiError(409, 'This registration has been cancelled.', { reason: 'CANCELLED' });
  }
  if (registration.status === 'Pending Payment') {
    throw new ApiError(409, 'Payment has not been completed for this registration.', {
      reason: 'PAYMENT_PENDING',
    });
  }
  if (ENDED_LIFECYCLES.has(event.lifecycle)) {
    throw new ApiError(409, 'This event has ended or was cancelled.', { reason: 'EVENT_ENDED' });
  }

  const student = await User.findById(registration.studentId).select(
    'fullName rollNumber phone branch year profilePictureUrl'
  );

  return { registration, event, student };
}

/**
 * Validates a scanned QR code and returns the attendee's info without
 * mutating anything — used by the organizer scanner to show "who is
 * this" before committing to a check-in/check-out action.
 */
export const validateQr = asyncHandler(async (req, res) => {
  const { qrToken, eventId } = req.body;
  if (!qrToken) throw new ApiError(400, 'qrToken is required');

  const { registration, event, student } = await resolveScannedRegistration({
    qrToken,
    eventId,
    collegeId: req.collegeId,
  });

  const attendance = await Attendance.findOne({
    collegeId: req.collegeId,
    eventId: registration.eventId,
    registrationId: registration._id,
  });

  res.json({
    success: true,
    data: {
      registration,
      event: { _id: event._id, title: event.title },
      student,
      attendance: attendance
        ? {
            checkedIn: attendance.checkedIn,
            checkedOut: attendance.checkedOut,
            checkInTime: attendance.checkInTime,
            checkOutTime: attendance.checkOutTime,
          }
        : { checkedIn: false, checkedOut: false, checkInTime: null, checkOutTime: null },
    },
  });
});

export const checkIn = asyncHandler(async (req, res) => {
  const { qrToken, eventId, scannerDevice } = req.body;
  if (!qrToken) throw new ApiError(400, 'qrToken is required');

  const { registration, event, student } = await resolveScannedRegistration({
    qrToken,
    eventId,
    collegeId: req.collegeId,
  });

  let attendance = await Attendance.findOne({
    collegeId: req.collegeId,
    eventId: registration.eventId,
    registrationId: registration._id,
  });

  if (attendance?.checkedIn) {
    throw new ApiError(
      409,
      `${student.fullName} was already checked in at ${attendance.checkInTime.toLocaleString()}.`,
      { reason: 'ALREADY_CHECKED_IN', checkInTime: attendance.checkInTime }
    );
  }

  if (attendance) {
    attendance.checkedIn = true;
    attendance.checkInTime = new Date();
    attendance.scannedBy = req.user._id;
    if (scannerDevice) attendance.scannerDevice = scannerDevice;
    await attendance.save();
  } else {
    attendance = await Attendance.create({
      collegeId: req.collegeId,
      eventId: registration.eventId,
      registrationId: registration._id,
      studentId: registration.studentId,
      checkedIn: true,
      checkInTime: new Date(),
      scannedBy: req.user._id,
      scannerDevice,
      scanMethod: 'QR',
    });
  }

  if (registration.status === 'Confirmed') {
    registration.status = 'Attended';
    await registration.save();
  }

  res.json({ success: true, data: { attendance, registration, student, event: { _id: event._id, title: event.title } } });
});

export const checkOut = asyncHandler(async (req, res) => {
  const { qrToken, eventId, scannerDevice } = req.body;
  if (!qrToken) throw new ApiError(400, 'qrToken is required');

  const { registration, student } = await resolveScannedRegistration({
    qrToken,
    eventId,
    collegeId: req.collegeId,
  });

  const attendance = await Attendance.findOne({
    collegeId: req.collegeId,
    eventId: registration.eventId,
    registrationId: registration._id,
  });

  if (!attendance || !attendance.checkedIn) {
    throw new ApiError(409, `${student.fullName} has not been checked in yet.`, {
      reason: 'NOT_CHECKED_IN',
    });
  }
  if (attendance.checkedOut) {
    throw new ApiError(
      409,
      `${student.fullName} was already checked out at ${attendance.checkOutTime.toLocaleString()}.`,
      { reason: 'ALREADY_CHECKED_OUT', checkOutTime: attendance.checkOutTime }
    );
  }

  attendance.checkedOut = true;
  attendance.checkOutTime = new Date();
  if (scannerDevice) attendance.scannerDevice = scannerDevice;
  await attendance.save();

  res.json({ success: true, data: { attendance, registration, student } });
});
