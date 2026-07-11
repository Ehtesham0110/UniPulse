import mongoose from 'mongoose';

const CertificateTemplateSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    name: { type: String, required: true },
    backgroundUrl: String,
    htmlTemplate: String,
    fields: [String],
    status: { type: String, enum: ['Active', 'Archived'], default: 'Active' },
  },
  { timestamps: true }
);

const CertificateSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true },
    registrationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Registration', required: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    templateId: { type: mongoose.Schema.Types.ObjectId, ref: 'CertificateTemplate' },
    certificateNumber: { type: String, required: true },
    // Public-facing URL the Flutter app calls (an authenticated API route,
    // not a raw static file path) — see certificate.service.js. `filePath`
    // is the actual local-disk location the download/preview endpoints
    // stream from; it's an internal implementation detail, never exposed
    // in API responses.
    pdfUrl: { type: String, required: true },
    filePath: { type: String, required: true, select: false },
    issuedAt: { type: Date, default: Date.now },
    generatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    regeneratedCount: { type: Number, default: 0 },
    status: { type: String, enum: ['Issued', 'Revoked'], default: 'Issued' },
  },
  { timestamps: true }
);

// One certificate per registration — this is the source of truth for
// duplicate-generation prevention (also enforced defensively in the
// service layer with a friendlier error before ever hitting the DB).
CertificateSchema.index({ collegeId: 1, eventId: 1, registrationId: 1 }, { unique: true });
CertificateSchema.index({ collegeId: 1, certificateNumber: 1 }, { unique: true });

export const CertificateTemplate = mongoose.model('CertificateTemplate', CertificateTemplateSchema);
export const Certificate = mongoose.model('Certificate', CertificateSchema);
