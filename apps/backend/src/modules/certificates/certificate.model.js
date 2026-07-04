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
    generatedPdfUrl: String,
    uploadedPdfUrl: String,
    previewImageUrl: String,
    issuedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    issuedAt: Date,
    status: { type: String, enum: ['Draft', 'Generated', 'Uploaded', 'Issued', 'Revoked'], default: 'Draft' },
  },
  { timestamps: true }
);

export const CertificateTemplate = mongoose.model('CertificateTemplate', CertificateTemplateSchema);
export const Certificate = mongoose.model('Certificate', CertificateSchema);

