import mongoose from 'mongoose';

const TeamMemberSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    teamId: { type: mongoose.Schema.Types.ObjectId, ref: 'Team', required: true, index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    fullName: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true },
    rollNumber: { type: String, trim: true, uppercase: true },
    role: { type: String, enum: ['Leader', 'Member'], default: 'Member' },
  },
  { timestamps: true }
);

const TeamSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true, index: true },
    registrationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Registration' },
    teamName: { type: String, required: true, trim: true },
    leaderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    status: { type: String, enum: ['Draft', 'Registered', 'Cancelled'], default: 'Draft' },
  },
  { timestamps: true }
);

TeamSchema.index({ collegeId: 1, eventId: 1, teamName: 1 }, { unique: true });

export const Team = mongoose.model('Team', TeamSchema);
export const TeamMember = mongoose.model('TeamMember', TeamMemberSchema);

