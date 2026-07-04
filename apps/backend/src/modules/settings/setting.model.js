import mongoose from 'mongoose';

const SettingSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, unique: true },
    approvalWorkflowEnabled: { type: Boolean, default: false },
    branding: {
      logoUrl: String,
      primaryColor: String,
      secondaryColor: String,
    },
    certificateDefaults: {
      templateId: { type: mongoose.Schema.Types.ObjectId, ref: 'CertificateTemplate' },
    },
    notificationDefaults: {
      senderName: String,
    },
  },
  { timestamps: true }
);

export const Setting = mongoose.model('Setting', SettingSchema);

