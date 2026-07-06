// Verification harness for the Payments milestone. Same approach as the
// registration/events tests: no MongoDB and no real Razorpay API access
// are available in this sandbox, so this mocks only the Mongoose model
// methods used and the Razorpay client's orders.create call, then runs
// the real, unmodified controller functions against them.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';

function matches(doc, query) {
  for (const [key, value] of Object.entries(query)) {
    if (value && typeof value === 'object' && '$in' in value) {
      if (!value.$in.map(String).includes(String(doc[key]))) return false;
      continue;
    }
    if (String(doc[key]) !== String(value)) return false;
  }
  return true;
}

let seq = 1;
function makeFakeModel() {
  const store = new Map();
  const withHelpers = (doc) => {
    if (!doc.save) doc.save = async function () { store.set(this._id, this); return this; };
    return doc;
  };
  return {
    store,
    async create(doc) {
      const _id = doc._id || `id_${seq++}`;
      const created = withHelpers({ ...doc, _id });
      store.set(_id, created);
      return created;
    },
    async findOne(query) {
      for (const doc of store.values()) if (matches(doc, query)) return withHelpers(doc);
      return null;
    },
    async findById(id) {
      const doc = store.get(id);
      return doc ? withHelpers(doc) : null;
    },
    async findByIdAndUpdate(id, update) {
      const doc = store.get(id);
      if (!doc) return null;
      if (update.$inc) {
        for (const [k, v] of Object.entries(update.$inc)) doc[k] = (doc[k] ?? 0) + v;
      }
      for (const [k, v] of Object.entries(update)) {
        if (k !== '$inc') doc[k] = v;
      }
      return withHelpers(doc);
    },
  };
}

const { Payment } = await import('../src/modules/payments/payment.model.js');
const { Registration } = await import('../src/modules/registrations/registration.model.js');
const { Event } = await import('../src/modules/events/event.model.js');
const razorpayConfig = await import('../src/config/razorpay.js');

Object.assign(Payment, makeFakeModel());
Object.assign(Registration, makeFakeModel());
Object.assign(Event, makeFakeModel());

// Fake Razorpay client: same shape as the real SDK's `orders.create`,
// used via the same getRazorpayClient() singleton the controller calls.
let orderCounter = 1;
const RAZORPAY_KEY_SECRET = 'test_key_secret';
const fakeRazorpayClient = {
  orders: {
    create: async ({ amount, currency, receipt }) => ({
      id: `order_fake_${orderCounter++}`,
      amount,
      currency,
      receipt,
      status: 'created',
    }),
  },
};
// env.js reads process.env at import time, so patch the already-loaded
// singleton directly for this test process.
process.env.RAZORPAY_KEY_ID = 'test_key_id';
process.env.RAZORPAY_KEY_SECRET = RAZORPAY_KEY_SECRET;
const { env } = await import('../src/config/env.js');
env.razorpayKeyId = 'test_key_id';
env.razorpayKeySecret = RAZORPAY_KEY_SECRET;

// getRazorpayClient() returns a real Razorpay SDK instance; the module
// namespace itself is read-only in ESM, but the instance's `orders`
// object is a plain mutable object, so we swap its `create` method for
// our fake — the controller calls the exact same singleton instance.
const realClient = razorpayConfig.getRazorpayClient();
realClient.orders.create = fakeRazorpayClient.orders.create;

const { createOrder, verifyPayment, failPayment } = await import(
  '../src/modules/payments/payment.controller.js'
);

function makeRes() {
  const res = { statusCode: 200 };
  res.status = (code) => { res.statusCode = code; return res; };
  res.json = (body) => { res.body = body; };
  return res;
}
async function call(handler, req) {
  const res = makeRes();
  let caughtError = null;
  await handler(req, res, (err) => { caughtError = err; });
  if (caughtError) {
    return { status: caughtError.statusCode ?? 500, body: { success: false, message: caughtError.message } };
  }
  return { status: res.statusCode, body: res.body };
}

function sign(orderId, paymentId, secret = RAZORPAY_KEY_SECRET) {
  return crypto.createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex');
}

const collegeId = 'college_1';
const student = { _id: 'user_student', collegeId };

let passed = 0;
function ok(label) { passed++; console.log(`  ✔ ${label}`); }

console.log('Payments milestone — mock-backed controller verification\n');

await Event.create({
  _id: 'event_paid', collegeId, title: 'Paid Workshop', paid: true, price: 500,
  maximumParticipants: 1, currentParticipants: 0,
});
await Registration.create({
  _id: 'reg_1', collegeId, eventId: 'event_paid', studentId: student._id,
  qrTokenHash: 'hash1', status: 'Pending Payment',
});

// ---- createOrder: validation ----
{
  const missing = await call(createOrder, { body: {}, user: student, collegeId });
  assert.equal(missing.status, 400);
  ok('createOrder rejects a missing registrationId');

  const notFound = await call(createOrder, { body: { registrationId: 'nope' }, user: student, collegeId });
  assert.equal(notFound.status, 404);
  ok('createOrder rejects a registration that does not exist');
}

// ---- createOrder: happy path + idempotent reuse ----
let orderId, paymentId;
{
  const first = await call(createOrder, { body: { registrationId: 'reg_1' }, user: student, collegeId });
  assert.equal(first.status, 201);
  assert.ok(first.body.data.orderId.startsWith('order_fake_'));
  assert.equal(first.body.data.amount, 500);
  orderId = first.body.data.orderId;
  paymentId = first.body.data.paymentId;
  ok('createOrder creates a Razorpay order and a Payment record');

  const second = await call(createOrder, { body: { registrationId: 'reg_1' }, user: student, collegeId });
  assert.equal(second.status, 201);
  assert.equal(second.body.data.orderId, orderId, 'should reuse the existing Created payment, not make a new order');
  ok('createOrder reuses an existing unpaid order instead of creating a duplicate');
}

// ---- createOrder: rejects for a non-paid event ----
{
  await Event.create({ _id: 'event_free', collegeId, title: 'Free Meetup', paid: false, price: 0 });
  await Registration.create({
    _id: 'reg_free', collegeId, eventId: 'event_free', studentId: student._id,
    qrTokenHash: 'hash2', status: 'Pending Payment',
  });
  const result = await call(createOrder, { body: { registrationId: 'reg_free' }, user: student, collegeId });
  assert.equal(result.status, 409);
  ok('createOrder rejects an event that does not require payment');
}

// ---- createOrder: capacity check ----
{
  await Event.findByIdAndUpdate('event_paid', { $inc: { currentParticipants: 1 } }); // simulate event now full
  await Registration.create({
    _id: 'reg_2', collegeId, eventId: 'event_paid', studentId: 'user_other',
    qrTokenHash: 'hash3', status: 'Pending Payment',
  });
  const result = await call(createOrder, { body: { registrationId: 'reg_2' }, user: { _id: 'user_other', collegeId }, collegeId });
  assert.equal(result.status, 409);
  assert.match(result.body.message, /maximum number of participants/i);
  ok('createOrder rejects when the event is already at capacity');
  await Event.findByIdAndUpdate('event_paid', { $inc: { currentParticipants: -1 } }); // restore for later checks
}

// ---- verifyPayment: validation + not found ----
{
  const missing = await call(verifyPayment, { body: {}, user: student, collegeId });
  assert.equal(missing.status, 400);
  ok('verifyPayment rejects a missing signature payload');

  const notFound = await call(verifyPayment, {
    body: { razorpay_order_id: 'order_does_not_exist', razorpay_payment_id: 'pay_x', razorpay_signature: 'sig' },
    user: student, collegeId,
  });
  assert.equal(notFound.status, 404);
  ok('verifyPayment rejects an unknown order id');
}

// ---- verifyPayment: bad signature ----
{
  const result = await call(verifyPayment, {
    body: { razorpay_order_id: orderId, razorpay_payment_id: 'pay_123', razorpay_signature: 'tampered' },
    user: student, collegeId,
  });
  assert.equal(result.status, 400);
  const payment = await Payment.findById(paymentId);
  assert.equal(payment.status, 'Created', 'payment status should be untouched after a bad signature');
  ok('verifyPayment rejects a tampered signature without mutating state');
}

// ---- verifyPayment: happy path ----
{
  const validSignature = sign(orderId, 'pay_123');
  const result = await call(verifyPayment, {
    body: { razorpay_order_id: orderId, razorpay_payment_id: 'pay_123', razorpay_signature: validSignature },
    user: student, collegeId,
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.registration.status, 'Confirmed');
  assert.equal(result.body.data.payment.status, 'Paid');
  ok('verifyPayment confirms the registration on a valid signature');

  const event = await Event.findById('event_paid');
  assert.equal(event.currentParticipants, 1, 'capacity should increment only after successful payment');
  ok('Event capacity increments only after payment is verified');
}

// ---- verifyPayment: duplicate verification is idempotent ----
{
  const validSignature = sign(orderId, 'pay_123');
  const result = await call(verifyPayment, {
    body: { razorpay_order_id: orderId, razorpay_payment_id: 'pay_123', razorpay_signature: validSignature },
    user: student, collegeId,
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.alreadyVerified, true);
  ok('verifyPayment is idempotent — re-verifying an already-paid order does not reprocess it');

  const event = await Event.findById('event_paid');
  assert.equal(event.currentParticipants, 1, 'capacity must NOT increment a second time');
  ok('Duplicate verification does not double-increment capacity');
}

// ---- failPayment ----
{
  await Registration.create({
    _id: 'reg_3', collegeId, eventId: 'event_free', studentId: 'user_c',
    qrTokenHash: 'hash4', status: 'Pending Payment',
  });
  // Manually create a fresh Created payment for a distinct scenario.
  await Event.findByIdAndUpdate('event_free', { paid: true, price: 100 });
  const orderResult = await call(createOrder, { body: { registrationId: 'reg_3' }, user: { _id: 'user_c', collegeId }, collegeId });
  assert.equal(orderResult.status, 201);
  const failPaymentId = orderResult.body.data.paymentId;

  const failResult = await call(failPayment, { params: { paymentId: failPaymentId }, user: { _id: 'user_c', collegeId }, collegeId });
  assert.equal(failResult.status, 200);
  assert.equal(failResult.body.data.status, 'Failed');
  ok('failPayment marks a payment attempt as Failed');

  const registration = await Registration.findOne({ _id: 'reg_3' });
  assert.equal(registration.status, 'Pending Payment', 'registration should remain Pending Payment so the user can retry');
  ok('Registration stays Pending Payment after a failed payment attempt (retryable)');

  const retryResult = await call(createOrder, { body: { registrationId: 'reg_3' }, user: { _id: 'user_c', collegeId }, collegeId });
  assert.equal(retryResult.status, 201);
  assert.notEqual(retryResult.body.data.paymentId, failPaymentId, 'retry should create a fresh payment, not reuse the failed one');
  ok('A new order can be created after a failed payment (retry flow)');

  const doubleFail = await call(failPayment, { params: { paymentId: failPaymentId }, user: { _id: 'user_c', collegeId }, collegeId });
  assert.equal(doubleFail.status, 200);
  ok('failPayment is safe to call again on an already-failed payment');
}

// ---- failPayment: cannot fail an already-paid payment ----
{
  const result = await call(failPayment, { params: { paymentId }, user: student, collegeId });
  assert.equal(result.status, 409);
  ok('failPayment refuses to mark an already-Paid payment as failed');
}

console.log(`\n${passed} checks passed.`);
