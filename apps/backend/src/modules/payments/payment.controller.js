import crypto from 'node:crypto';
import { asyncHandler } from '../../shared/utils/async-handler.js';
import { ApiError } from '../../shared/errors/api-error.js';
import { env } from '../../config/env.js';
import { getRazorpayClient } from '../../config/razorpay.js';
import { Payment } from './payment.model.js';
import { Registration } from '../registrations/registration.model.js';
import { Event } from '../events/event.model.js';

/**
 * Creates (or reuses) a Razorpay order for a registration that is awaiting
 * payment. Idempotent: if a `Created` (not yet paid) payment already
 * exists for this registration, its existing order is returned rather
 * than creating a second Razorpay order — this is what happens if the
 * Flutter app calls this again after e.g. a network hiccup before the
 * checkout sheet opened.
 */
export const createOrder = asyncHandler(async (req, res) => {
  const { registrationId } = req.body;
  if (!registrationId) throw new ApiError(400, 'registrationId is required');

  const registration = await Registration.findOne({
    _id: registrationId,
    collegeId: req.collegeId,
    studentId: req.user._id,
  });
  if (!registration) throw new ApiError(404, 'Registration not found');

  if (registration.status !== 'Pending Payment') {
    throw new ApiError(409, `This registration is not awaiting payment (status: ${registration.status})`);
  }

  const event = await Event.findOne({ _id: registration.eventId, collegeId: req.collegeId });
  if (!event) throw new ApiError(404, 'Event not found');
  if (!event.paid || !(event.price > 0)) {
    throw new ApiError(409, 'This event does not require payment');
  }

  // Capacity is enforced here (before money changes hands) rather than at
  // registration time, since Pending Payment registrations for paid
  // events aren't capacity-limited at creation — this is the point a
  // student is actually about to claim a confirmed slot.
  if (event.maximumParticipants != null && event.currentParticipants >= event.maximumParticipants) {
    throw new ApiError(409, 'This event has reached its maximum number of participants');
  }

  let payment = await Payment.findOne({ registrationId: registration._id, status: 'Created' });

  if (!payment) {
    let order;
    try {
      const razorpay = getRazorpayClient();
      order = await razorpay.orders.create({
        amount: Math.round(event.price * 100), // paise
        currency: 'INR',
        receipt: registration._id.toString(),
        notes: {
          eventId: event._id.toString(),
          registrationId: registration._id.toString(),
          studentId: req.user._id.toString(),
        },
      });
    } catch (error) {
      throw new ApiError(502, 'Could not create the payment order. Please try again.');
    }

    payment = await Payment.create({
      collegeId: req.collegeId,
      eventId: event._id,
      registrationId: registration._id,
      studentId: req.user._id,
      provider: 'Razorpay',
      providerOrderId: order.id,
      amount: event.price,
      currency: 'INR',
      status: 'Created',
    });

    registration.paymentId = payment._id;
    await registration.save();
  }

  res.status(201).json({
    success: true,
    data: {
      paymentId: payment._id,
      orderId: payment.providerOrderId,
      amount: payment.amount,
      currency: payment.currency,
      keyId: env.razorpayKeyId,
      registrationId: registration._id,
    },
  });
});

/**
 * Verifies a completed Razorpay checkout using the standard HMAC-SHA256
 * signature scheme (order_id|payment_id signed with the key secret), then
 * confirms the registration and consumes an event capacity slot.
 *
 * Idempotent: calling this again for an already-`Paid` payment returns
 * success without re-processing (no double capacity increment), which
 * matters because a flaky network can cause the Flutter client to retry
 * the same verification call.
 */
export const verifyPayment = asyncHandler(async (req, res) => {
  const { razorpay_order_id: orderId, razorpay_payment_id: paymentId, razorpay_signature: signature } =
    req.body;

  if (!orderId || !paymentId || !signature) {
    throw new ApiError(400, 'razorpay_order_id, razorpay_payment_id and razorpay_signature are required');
  }

  const payment = await Payment.findOne({
    providerOrderId: orderId,
    collegeId: req.collegeId,
    studentId: req.user._id,
  });
  if (!payment) throw new ApiError(404, 'Payment not found');

  if (payment.status === 'Paid') {
    // Duplicate verification call — return success without reprocessing.
    return res.json({
      success: true,
      data: { alreadyVerified: true, registrationId: payment.registrationId },
    });
  }
  if (payment.status === 'Failed') {
    throw new ApiError(409, 'This payment was already marked as failed. Please start a new payment.');
  }

  const expectedSignature = crypto
    .createHmac('sha256', env.razorpayKeySecret)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');

  if (expectedSignature !== signature) {
    // Don't mutate payment/registration state on a bad signature — it
    // could be a transient client bug rather than a genuine failed
    // payment, and the user should be able to retry verification.
    throw new ApiError(400, 'Payment verification failed: invalid signature');
  }

  payment.providerPaymentId = paymentId;
  payment.providerSignature = signature;
  payment.status = 'Paid';
  payment.paidAt = new Date();
  await payment.save();

  const registration = await Registration.findOne({
    _id: payment.registrationId,
    collegeId: req.collegeId,
  });
  if (!registration) throw new ApiError(404, 'Registration not found for this payment');

  if (registration.status === 'Pending Payment') {
    registration.status = 'Confirmed';
    await registration.save();
    // NOTE: capacity was already checked in createOrder, and this
    // increment is unconditional rather than re-checked against
    // maximumParticipants here. In the rare case where multiple students
    // complete payment for the last slot(s) at the exact same moment,
    // the event could end up very slightly over capacity. A proper fix
    // needs a reservation/hold system or DB transactions — out of scope
    // for this milestone; a real payment that already succeeded should
    // not be silently discarded.
    await Event.findByIdAndUpdate(registration.eventId, { $inc: { currentParticipants: 1 } });
  }

  res.json({ success: true, data: { registration, payment } });
});

/**
 * Reports that a payment attempt failed or was cancelled by the user
 * (e.g. they dismissed the Razorpay checkout sheet). The registration
 * itself stays `Pending Payment` so the student can retry — only this
 * specific payment attempt is marked Failed.
 */
export const failPayment = asyncHandler(async (req, res) => {
  const payment = await Payment.findOne({
    _id: req.params.paymentId,
    collegeId: req.collegeId,
    studentId: req.user._id,
  });
  if (!payment) throw new ApiError(404, 'Payment not found');

  if (payment.status === 'Paid') {
    throw new ApiError(409, 'This payment already succeeded and cannot be marked as failed');
  }

  payment.status = 'Failed';
  await payment.save();

  res.json({ success: true, data: payment });
});
