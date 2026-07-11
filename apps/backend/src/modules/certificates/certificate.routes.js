import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requirePermission } from '../../middleware/require-permission.js';
import { Permissions } from '../../shared/utils/roles.js';
import {
  listMyCertificates,
  viewCertificate,
  downloadCertificate,
  createCertificate,
  bulkGenerateCertificates,
  reissueCertificate,
  createCertificateTemplate,
  listCertificateTemplates,
} from './certificate.controller.js';

export const certificateRouter = Router();

certificateRouter.use(authenticate);

certificateRouter.get('/me', listMyCertificates);
certificateRouter.get('/:certificateId/view', viewCertificate);
certificateRouter.get('/:certificateId/download', downloadCertificate);

certificateRouter.post('/generate', requirePermission(Permissions.ISSUE_CERTIFICATES), createCertificate);
certificateRouter.post(
  '/bulk-generate',
  requirePermission(Permissions.ISSUE_CERTIFICATES),
  bulkGenerateCertificates
);
certificateRouter.post(
  '/:certificateId/regenerate',
  requirePermission(Permissions.ISSUE_CERTIFICATES),
  reissueCertificate
);

certificateRouter.post(
  '/templates',
  requirePermission(Permissions.ISSUE_CERTIFICATES),
  createCertificateTemplate
);
certificateRouter.get(
  '/templates',
  requirePermission(Permissions.ISSUE_CERTIFICATES),
  listCertificateTemplates
);
