import mongoose from 'mongoose';

const RegistrationSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true, index: true },
    studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    teamId: { type: mongoose.Schema.Types.ObjectId, ref: 'Team' },
    paymentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Payment' },
    certificateId: { type: mongoose.Schema.Types.ObjectId, ref: 'Certificate' },
    qrTokenHash: { type: String, required: true, unique: true },
    qrImageUrl: String,
    status: {
      type: String,
      enum: ['Pending Payment', 'Confirmed', 'Cancelled', 'Attended', 'Completed'],
      default: 'Confirmed',
      index: true,
    },
  },
  { timestamps: true }
);

RegistrationSchema.index({ collegeId: 1, eventId: 1, studentId: 1 }, { unique: true });

export const Registration = mongoose.model('Registration', RegistrationSchema);

