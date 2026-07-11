import mongoose from 'mongoose';

export const EventLifecycle = Object.freeze({
  DRAFT: 'Draft',
  PENDING_APPROVAL: 'Pending Approval',
  PUBLISHED: 'Published',
  REGISTRATION_OPEN: 'Registration Open',
  REGISTRATION_CLOSED: 'Registration Closed',
  LIVE: 'Live',
  COMPLETED: 'Completed',
  ARCHIVED: 'Archived',
  CANCELLED: 'Cancelled',
});

const MediaSchema = new mongoose.Schema(
  {
    bannerUrl: String,
    thumbnailUrl: String,
    galleryUrls: [String],
  },
  { _id: false }
);

const ScheduleItemSchema = new mongoose.Schema(
  {
    time: String,
    title: String,
    description: String,
    order: Number,
  },
  { _id: false }
);

const OrganizerSchema = new mongoose.Schema(
  {
    name: String,
    contactNumber: String,
    email: String,
  },
  { _id: false }
);

const ApprovalSchema = new mongoose.Schema(
  {
    required: { type: Boolean, default: true },
    submittedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    submittedAt: Date,
    reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    reviewedAt: Date,
    decision: { type: String, enum: ['Pending', 'Approved', 'Rejected'], default: 'Pending' },
    notes: String,
  },
  { _id: false }
);

const EventSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    clubId: { type: mongoose.Schema.Types.ObjectId, ref: 'Club', required: true, index: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    assignedOrganizerIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    title: { type: String, required: true, trim: true },
    slug: { type: String, required: true, trim: true },
    description: { type: String, required: true },
    category: { type: String, enum: ['Tech', 'Non Tech'], required: true, index: true },
    media: MediaSchema,
    venue: { type: String, required: true },
    registrationStart: Date,
    registrationEnd: Date,
    eventDate: { type: Date, required: true, index: true },
    startTime: String,
    endTime: String,
    eventType: { type: String, enum: ['Individual', 'Team'], required: true },
    teamMin: { type: Number, default: 1 },
    teamMax: { type: Number, default: 1 },
    paid: { type: Boolean, default: false },
    price: { type: Number, default: 0 },
    highlights: [String],
    schedule: [ScheduleItemSchema],
    rules: [String],
    requirements: [String],
    organizer: OrganizerSchema,
    maximumParticipants: Number,
    currentParticipants: { type: Number, default: 0 },
    // Additive field for the Certificates milestone — which template to
    // use when generating certificates for this event. Optional; a
    // generate/bulk-generate call can also pass a templateId explicitly.
    certificateTemplateId: { type: mongoose.Schema.Types.ObjectId, ref: 'CertificateTemplate' },
    lifecycle: {
      type: String,
      enum: Object.values(EventLifecycle),
      default: EventLifecycle.DRAFT,
      index: true,
    },
    approval: ApprovalSchema,
    templateKey: String,
  },
  { timestamps: true }
);

EventSchema.index({ collegeId: 1, slug: 1 }, { unique: true });
EventSchema.index({ collegeId: 1, lifecycle: 1, eventDate: 1 });

export const Event = mongoose.model('Event', EventSchema);

