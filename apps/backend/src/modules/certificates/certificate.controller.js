import fs from 'node:fs';
import { asyncHandler } from '../../shared/utils/async-handler.js';
import { ApiError } from '../../shared/errors/api-error.js';
import { Permissions, roleHasPermission } from '../../shared/utils/roles.js';
import { Certificate, CertificateTemplate } from './certificate.model.js';
import {
  generateCertificate,
  regenerateCertificate,
  bulkGenerateForEvent,
} from './certificate.service.js';

function canAccessCertificate(user, certificate) {
  if (roleHasPermission(user.role, Permissions.ISSUE_CERTIFICATES)) return true;
  return certificate.userId.toString() === user._id.toString();
}

export const listMyCertificates = asyncHandler(async (req, res) => {
  const certificates = await Certificate.find({ collegeId: req.collegeId, userId: req.user._id })
    .populate('eventId', 'title eventDate venue category media.thumbnailUrl')
    .sort({ issuedAt: -1 });

  res.json({ success: true, data: certificates });
});

async function streamCertificate(req, res, disposition) {
  const certificate = await Certificate.findOne({
    _id: req.params.certificateId,
    collegeId: req.collegeId,
  }).select('+filePath');
  if (!certificate) throw new ApiError(404, 'Certificate not found');

  if (!canAccessCertificate(req.user, certificate)) {
    throw new ApiError(403, 'You do not have permission to access this certificate');
  }

  if (!fs.existsSync(certificate.filePath)) {
    throw new ApiError(404, 'The certificate file is missing. Please ask an admin to regenerate it.');
  }

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader(
    'Content-Disposition',
    `${disposition}; filename="${certificate.certificateNumber}.pdf"`
  );
  fs.createReadStream(certificate.filePath).pipe(res);
}

/** Streams the PDF for inline viewing in-browser/in-app. */
export const viewCertificate = asyncHandler(async (req, res) => {
  await streamCertificate(req, res, 'inline');
});

/** Streams the PDF as a forced download/attachment. */
export const downloadCertificate = asyncHandler(async (req, res) => {
  await streamCertificate(req, res, 'attachment');
});

export const createCertificate = asyncHandler(async (req, res) => {
  const { registrationId, templateId } = req.body;
  if (!registrationId) throw new ApiError(400, 'registrationId is required');

  const certificate = await generateCertificate({
    collegeId: req.collegeId,
    registrationId,
    templateId,
    generatedBy: req.user._id,
  });

  res.status(201).json({ success: true, data: certificate });
});

export const bulkGenerateCertificates = asyncHandler(async (req, res) => {
  const { eventId, templateId } = req.body;
  if (!eventId) throw new ApiError(400, 'eventId is required');

  const summary = await bulkGenerateForEvent({
    collegeId: req.collegeId,
    eventId,
    templateId,
    generatedBy: req.user._id,
  });

  res.status(201).json({ success: true, data: summary });
});

/**
 * Regenerating replaces an already-issued certificate's PDF, so it
 * requires an explicit `confirm: true` in the body — this isn't
 * something that should ever happen as a side effect of a retried
 * request.
 */
export const reissueCertificate = asyncHandler(async (req, res) => {
  if (req.body.confirm !== true) {
    throw new ApiError(400, 'Set { "confirm": true } to explicitly confirm regeneration.');
  }

  const certificate = await regenerateCertificate({
    collegeId: req.collegeId,
    certificateId: req.params.certificateId,
    generatedBy: req.user._id,
  });

  res.json({ success: true, data: certificate });
});

export const createCertificateTemplate = asyncHandler(async (req, res) => {
  const { name, backgroundUrl, htmlTemplate, fields } = req.body;
  if (!name) throw new ApiError(400, 'name is required');

  const template = await CertificateTemplate.create({
    collegeId: req.collegeId,
    name,
    backgroundUrl,
    htmlTemplate,
    fields,
  });

  res.status(201).json({ success: true, data: template });
});

export const listCertificateTemplates = asyncHandler(async (req, res) => {
  const templates = await CertificateTemplate.find({
    collegeId: req.collegeId,
    status: 'Active',
  }).sort({ createdAt: -1 });

  res.json({ success: true, data: templates });
});
