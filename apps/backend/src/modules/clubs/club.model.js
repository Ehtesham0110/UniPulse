import mongoose from 'mongoose';

const ClubSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    name: { type: String, required: true, trim: true },
    description: String,
    logoUrl: String,
    category: { type: String, enum: ['Tech', 'Non Tech', 'Sports', 'Cultural', 'Academic'], required: true },
    organizerIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    status: { type: String, enum: ['Active', 'Archived'], default: 'Active' },
  },
  { timestamps: true }
);

ClubSchema.index({ collegeId: 1, name: 1 }, { unique: true });

export const Club = mongoose.model('Club', ClubSchema);

