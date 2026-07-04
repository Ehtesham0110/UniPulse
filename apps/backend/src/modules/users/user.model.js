import mongoose from 'mongoose';
import { Roles } from '../../shared/utils/roles.js';

const UserSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    fullName: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true },
    email: { type: String, trim: true, lowercase: true },
    rollNumber: { type: String, trim: true, uppercase: true },
    branch: { type: String, trim: true, uppercase: true },
    year: { type: Number, min: 1, max: 6 },
    role: { type: String, enum: Object.values(Roles), default: Roles.STUDENT, index: true },
    profilePictureUrl: String,
    bookmarks: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Event' }],
    fcmTokens: [String],
    assignedClubIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Club' }],
    status: { type: String, enum: ['Active', 'Suspended'], default: 'Active', index: true },
    lastActiveAt: Date,
  },
  { timestamps: true }
);

UserSchema.index({ collegeId: 1, phone: 1 }, { unique: true });
UserSchema.index({ collegeId: 1, rollNumber: 1 }, { sparse: true });

export const User = mongoose.model('User', UserSchema);

