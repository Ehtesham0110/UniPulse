import mongoose from 'mongoose';

const ContactSchema = new mongoose.Schema(
  {
    email: String,
    phone: String,
    supportEmail: String,
  },
  { _id: false }
);

const BrandingSchema = new mongoose.Schema(
  {
    logoUrl: String,
    primaryColor: { type: String, default: '#FF6B1A' },
    secondaryColor: { type: String, default: '#EC1E6C' },
    welcomeIllustrationUrl: String,
    treeAssetUrl: String,
  },
  { _id: false }
);

const CollegeSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    code: { type: String, required: true, unique: true, uppercase: true, trim: true },
    logoUrl: String,
    address: String,
    website: String,
    contact: ContactSchema,
    branding: BrandingSchema,
    status: { type: String, enum: ['Active', 'Suspended'], default: 'Active', index: true },
  },
  { timestamps: true }
);

export const College = mongoose.model('College', CollegeSchema);

