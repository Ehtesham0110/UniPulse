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
    recipientCount: { type: Number, default: 0 },
    sentAt: Date,
  },
  { timestamps: true }
);

export const Notification = mongoose.model('Notification', NotificationSchema);

// Per-recipient delivery record — one per (notification, user). This is
// what a student's "inbox" is actually queried from: it carries the
// read/unread state and a soft-delete flag that are meaningless on the
// shared broadcast (`Notification`) document itself.
const NotificationRecipientSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    notificationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Notification', required: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    isRead: { type: Boolean, default: false },
    readAt: Date,
    deletedAt: Date,
  },
  { timestamps: true }
);
NotificationRecipientSchema.index({ collegeId: 1, notificationId: 1, userId: 1 }, { unique: true });
NotificationRecipientSchema.index({ collegeId: 1, userId: 1, createdAt: -1 });

export const NotificationRecipient = mongoose.model(
  'NotificationRecipient',
  NotificationRecipientSchema
);

