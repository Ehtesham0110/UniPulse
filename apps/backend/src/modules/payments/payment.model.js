import mongoose from 'mongoose';

const PaymentSchema = new mongoose.Schema(
  {
    collegeId: { type: mongoose.Schema.Types.ObjectId, ref: 'College', required: true, index: true },
    eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true },
    registrationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Registration' },
    studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    provider: { type: String, enum: ['Razorpay'], default: 'Razorpay' },
    providerOrderId: String,
    providerPaymentId: String,
    providerSignature: String,
    amount: { type: Number, required: true },
    currency: { type: String, default: 'INR' },
    status: { type: String, enum: ['Created', 'Paid', 'Failed', 'Refunded'], default: 'Created', index: true },
    paidAt: Date,
  },
  { timestamps: true }
);

export const Payment = mongoose.model('Payment', PaymentSchema);

