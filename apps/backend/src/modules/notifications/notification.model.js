import mongoose from 'mongoose';

const AudienceSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: ['College', 'Branch', 'Year', 'Club', 'Event Participants', 'Individual Student'],
      required: true,
    },
    branch: String,
    year: Number,
    clubId: { type: mongoose.Schema.Types.ObjectId, ref: 'Club' },
    eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event' },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { _id: false }
);

const NotificationSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    title: { type: String, required: true },
    body: { type: String, required: true },
    imageUrl: String,
    audience: AudienceSchema,
    sentBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    status: { type: String, enum: ['Draft', 'Queued', 'Sent', 'Failed'], default: 'Draft' },
    sentAt: Date,
  },
  { timestamps: true }
);

export const Notification = mongoose.model('Notification', NotificationSchema);

