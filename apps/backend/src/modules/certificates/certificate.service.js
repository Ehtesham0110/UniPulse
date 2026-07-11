import { ApiError } from '../../shared/errors/api-error.js';
import { writeCertificatePdf, deleteCertificatePdf } from '../../shared/utils/certificate-pdf.js';
import { Certificate, CertificateTemplate } from './certificate.model.js';
import { Registration } from '../registrations/registration.model.js';
import { Event, EventLifecycle } from '../events/event.model.js';
import { Attendance } from '../attendance/attendance.model.js';
import { User } from '../users/user.model.js';
import { College } from '../colleges/college.model.js';

function buildCertificateNumber(registrationId) {
  const year = new Date().getFullYear();
  const shortId = registrationId.toString().slice(-8).toUpperCase();
  return `UNIPULSE-${year}-${shortId}`;
}

function pdfUrlFor(certificateId) {
  return `/api/certificates/${certificateId}/download`;
}

/**
 * Validates the full eligibility chain from the spec:
 *   Registration exists -> Payment completed (paid events) ->
 *   Attendance completed -> Event completed
 * and returns everything the caller needs (registration/event/student/
 * attendance) so it doesn't have to re-fetch them. Throws an ApiError
 * with a `reason` code for every failure so the UI can show a specific
 * message.
 */
async function resolveEligibleRegistration({ collegeId, registrationId }) {
  const registration = await Registration.findOne({ _id: registrationId, collegeId });
  if (!registration) throw new ApiError(404, 'Registration not found', { reason: 'NOT_FOUND' });

  const event = await Event.findOne({ _id: registration.eventId, collegeId });
  if (!event) throw new ApiError(404, 'Event not found', { reason: 'NOT_FOUND' });

  if (registration.status === 'Cancelled') {
    throw new ApiError(409, 'This registration was cancelled.', { reason: 'CANCELLED' });
  }
  if (registration.status === 'Pending Payment') {
    throw new ApiError(409, 'Payment has not been completed for this registration.', {
      reason: 'PAYMENT_PENDING',
    });
  }

  const attendance = await Attendance.findOne({
    collegeId,
    eventId: registration.eventId,
    registrationId: registration._id,
  });
  if (!attendance?.checkedIn) {
    throw new ApiError(409, 'This student did not attend the event.', {
      reason: 'NOT_ATTENDED',
    });
  }

  if (event.lifecycle !== EventLifecycle.COMPLETED) {
    throw new ApiError(409, 'Certificates can only be issued after the event is completed.', {
      reason: 'EVENT_NOT_COMPLETED',
    });
  }

  const student = await User.findById(registration.studentId);
  if (!student) throw new ApiError(404, 'Student not found', { reason: 'NOT_FOUND' });

  return { registration, event, student, attendance };
}

async function assertNoDuplicate({ collegeId, eventId, registrationId }) {
  const existing = await Certificate.findOne({ collegeId, eventId, registrationId });
  if (existing) {
    throw new ApiError(409, 'A certificate has already been issued for this registration.', {
      reason: 'DUPLICATE_CERTIFICATE',
      certificateId: existing._id,
    });
  }
}

/**
 * Generates a brand-new certificate for a registration. Rejects if one
 * already exists (see `regenerateCertificate` for reissuing).
 */
export async function generateCertificate({ collegeId, registrationId, templateId, generatedBy }) {
  const { registration, event, student } = await resolveEligibleRegistration({
    collegeId,
    registrationId,
  });

  await assertNoDuplicate({ collegeId, eventId: event._id, registrationId: registration._id });

  let template = null;
  const resolvedTemplateId = templateId ?? event.certificateTemplateId;
  if (resolvedTemplateId) {
    template = await CertificateTemplate.findOne({ _id: resolvedTemplateId, collegeId });
    if (!template) {
      throw new ApiError(422, 'templateId does not reference a valid template for your college');
    }
  }

  const college = await College.findById(collegeId);
  const certificateNumber = buildCertificateNumber(registration._id);
  const issuedAt = new Date();

  const filePath = await writeCertificatePdf({
    certificateNumber,
    studentName: student.fullName,
    eventTitle: event.title,
    collegeName: college?.name,
    issuedAt,
    templateName: template?.name,
  });

  try {
    const certificate = await Certificate.create({
      collegeId,
      eventId: event._id,
      registrationId: registration._id,
      userId: student._id,
      templateId: template?._id,
      certificateNumber,
      pdfUrl: '', // filled in right after we know the real _id
      filePath,
      issuedAt,
      generatedBy,
      regeneratedCount: 0,
    });
    certificate.pdfUrl = pdfUrlFor(certificate._id);
    await certificate.save();
    return certificate;
  } catch (error) {
    deleteCertificatePdf(filePath);
    if (error.code === 11000) {
      throw new ApiError(409, 'A certificate has already been issued for this registration.', {
        reason: 'DUPLICATE_CERTIFICATE',
      });
    }
    throw error;
  }
}

/**
 * Re-renders and replaces the PDF for an existing certificate (e.g. a
 * typo in the student's name was fixed, or the template changed). Keeps
 * the same certificateNumber and document id — only the file and
 * `issuedAt`/`generatedBy`/`regeneratedCount` change.
 */
export async function regenerateCertificate({ collegeId, certificateId, generatedBy }) {
  const certificate = await Certificate.findOne({ _id: certificateId, collegeId });
  if (!certificate) throw new ApiError(404, 'Certificate not found');

  const event = await Event.findOne({ _id: certificate.eventId, collegeId });
  const student = await User.findById(certificate.userId);
  const college = await College.findById(collegeId);
  const template = certificate.templateId
    ? await CertificateTemplate.findOne({ _id: certificate.templateId, collegeId })
    : null;

  if (!event || !student) throw new ApiError(404, 'Certificate references missing data');

  const oldFilePath = certificate.filePath;
  const newFilePath = await writeCertificatePdf({
    certificateNumber: certificate.certificateNumber,
    studentName: student.fullName,
    eventTitle: event.title,
    collegeName: college?.name,
    issuedAt: new Date(),
    templateName: template?.name,
  });

  certificate.filePath = newFilePath;
  certificate.issuedAt = new Date();
  certificate.generatedBy = generatedBy;
  certificate.regeneratedCount += 1;
  await certificate.save();

  if (oldFilePath && oldFilePath !== newFilePath) deleteCertificatePdf(oldFilePath);

  return certificate;
}

/**
 * Generates certificates for every attended, not-yet-certified
 * registration in a completed event. Never throws for individual
 * failures — collects them into the summary instead, since one
 * ineligible student shouldn't abort the whole batch.
 */
export async function bulkGenerateForEvent({ collegeId, eventId, templateId, generatedBy }) {
  const event = await Event.findOne({ _id: eventId, collegeId });
  if (!event) throw new ApiError(404, 'Event not found');
  if (event.lifecycle !== EventLifecycle.COMPLETED) {
    throw new ApiError(409, 'Certificates can only be issued after the event is completed.', {
      reason: 'EVENT_NOT_COMPLETED',
    });
  }

  const attendedRegistrations = await Registration.find({
    collegeId,
    eventId,
    status: 'Attended',
  });

  const generated = [];
  const skipped = [];

  for (const registration of attendedRegistrations) {
    try {
      const certificate = await generateCertificate({
        collegeId,
        registrationId: registration._id,
        templateId,
        generatedBy,
      });
      generated.push({ registrationId: registration._id, certificateId: certificate._id });
    } catch (error) {
      skipped.push({
        registrationId: registration._id,
        reason: error.details?.reason ?? 'ERROR',
        message: error.message,
      });
    }
  }

  return { totalEligible: attendedRegistrations.length, generated, skipped };
}
