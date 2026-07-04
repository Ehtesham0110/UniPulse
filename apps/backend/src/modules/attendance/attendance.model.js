import mongoose from 'mongoose';

const AttendanceSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true, index: true },
    registrationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Registration', required: true, index: true },
    studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    checkedIn: { type: Boolean, default: false },
    checkedOut: { type: Boolean, default: false },
    checkInTime: Date,
    checkOutTime: Date,
    scannerDevice: String,
    scannedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    scanMethod: { type: String, enum: ['QR', 'Manual'], required: true },
  },
  { timestamps: true }
);

AttendanceSchema.index({ collegeId: 1, eventId: 1, registrationId: 1 }, { unique: true });

export const Attendance = mongoose.model('Attendance', AttendanceSchema);

