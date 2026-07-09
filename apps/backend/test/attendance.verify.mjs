// Verification harness for the QR Attendance milestone. Same approach as
// prior milestones: no MongoDB in this sandbox, so this mocks only the
// Mongoose model methods used, and runs the real, unmodified controller
// functions (including the real crypto-based QR token logic) against them.
import assert from 'node:assert/strict';

function evalExpr(expr, doc) {
  if (expr.$or) return expr.$or.some((e) => evalExpr(e, doc));
  if (expr.$and) return expr.$and.every((e) => evalExpr(e, doc));
  if (expr.$eq) return resolveVal(expr.$eq[0], doc) === resolveVal(expr.$eq[1], doc);
  if (expr.$lt) return resolveVal(expr.$lt[0], doc) < resolveVal(expr.$lt[1], doc);
  throw new Error('unsupported $expr: ' + JSON.stringify(expr));
}
function resolveVal(v, doc) {
  return typeof v === 'string' && v.startsWith('$') ? doc[v.slice(1)] : v;
}
function matches(doc, query) {
  for (const [key, value] of Object.entries(query)) {
    if (key === '$expr') {
      if (!evalExpr(value, doc)) return false;
      continue;
    }
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
    if (!doc.save) doc.save = async function () { store.set(this._id.toString(), this); return this; };
    return doc;
  };
  return {
    store,
    async create(doc) {
      const _id = doc._id || `id_${seq++}`;
      const created = withHelpers({ ...doc, _id });
      store.set(_id.toString(), created);
      return created;
    },
    async findOne(query) {
      for (const doc of store.values()) if (matches(doc, query)) return withHelpers(doc);
      return null;
    },
    async findById(id) {
      const doc = store.get(id?.toString());
      return doc ? withHelpers(doc) : null;
    },
    async findOneAndUpdate(query, update) {
      for (const doc of store.values()) {
        if (matches(doc, query)) {
          if (update.$inc) {
            for (const [k, v] of Object.entries(update.$inc)) doc[k] = (doc[k] ?? 0) + v;
          }
          for (const [k, v] of Object.entries(update)) {
            if (k !== '$inc') doc[k] = v;
          }
          return withHelpers(doc);
        }
      }
      return null;
    },
    async findByIdAndUpdate(id, update) {
      const doc = store.get(id?.toString());
      if (!doc) return null;
      if (update.$inc) {
        for (const [k, v] of Object.entries(update.$inc)) doc[k] = (doc[k] ?? 0) + v;
      }
      for (const [k, v] of Object.entries(update)) {
        if (k !== '$inc') doc[k] = v;
      }
      return withHelpers(doc);
    },
    async findByIdAndDelete(id) {
      const doc = store.get(id?.toString()) ?? null;
      store.delete(id?.toString());
      return doc;
    },
    select() { return this; }, // supports User.findById(...).select('...') chaining below
  };
}

// User.findById(...).select(...) needs the returned promise itself to be
// chainable with .select(); Mongoose supports this via query thenables.
// The real controller does `await User.findById(id).select('...')`, so we
// make findById return a thenable object with a no-op `.select()`.
function makeFakeUserModel() {
  const store = new Map();
  return {
    store,
    async create(doc) {
      const _id = doc._id || `id_${seq++}`;
      const created = { ...doc, _id };
      store.set(_id.toString(), created);
      return created;
    },
    findById(id) {
      const doc = store.get(id?.toString()) ?? null;
      const result = Promise.resolve(doc);
      result.select = () => result;
      return result;
    },
  };
}

const { Registration } = await import('../src/modules/registrations/registration.model.js');
const { Event, EventLifecycle } = await import('../src/modules/events/event.model.js');
const { Attendance } = await import('../src/modules/attendance/attendance.model.js');
const { User } = await import('../src/modules/users/user.model.js');
const { buildQrToken, extractRegistrationId } = await import('../src/shared/utils/qr-token.js');

Object.assign(Registration, makeFakeModel());
Object.assign(Event, makeFakeModel());
Object.assign(Attendance, makeFakeModel());
Object.assign(User, makeFakeUserModel());

const { validateQr, checkIn, checkOut } = await import('../src/modules/attendance/attendance.controller.js');
const { getRegistrationQr, registerForEvent } = await import(
  '../src/modules/registrations/registration.controller.js'
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
    return { status: caughtError.statusCode ?? 500, body: { success: false, message: caughtError.message, details: caughtError.details } };
  }
  return { status: res.statusCode, body: res.body };
}

const collegeId = 'college_1';
const organizer = { _id: 'user_organizer', collegeId, role: 'Organizer' };
const student = {
  _id: 'user_student', collegeId, role: 'Student',
  fullName: 'Asha Rao', phone: '+919000000001', rollNumber: 'VU1',
};
await User.create(student);

let passed = 0;
function ok(label) { passed++; console.log(`  ✔ ${label}`); }

console.log('QR Attendance milestone — mock-backed controller verification\n');

// ---- QR token round-trip via real registration creation ----
let confirmedRegistrationId, confirmedQrToken;
{
  await Event.create({
    _id: 'event_free', collegeId, title: 'Open Mic Night', eventType: 'Individual',
    teamMin: 1, teamMax: 1, paid: false, maximumParticipants: null, currentParticipants: 0,
    lifecycle: EventLifecycle.REGISTRATION_OPEN,
  });

  const result = await call(registerForEvent, { body: { eventId: 'event_free' }, user: student, collegeId });
  assert.equal(result.status, 201);
  confirmedRegistrationId = result.body.data.registration._id;
  confirmedQrToken = result.body.data.qrToken;

  const resolvedId = extractRegistrationId(confirmedQrToken);
  assert.equal(resolvedId, confirmedRegistrationId.toString());
  ok('A newly-issued QR token round-trips back to the correct registration id');

  const tampered = confirmedQrToken.slice(0, -2) + 'zz';
  assert.equal(extractRegistrationId(tampered), null);
  ok('A tampered QR token fails signature verification');

  assert.equal(extractRegistrationId('not-a-qr-token-at-all'), null);
  ok('A malformed QR token is rejected without throwing');
}

// ---- getRegistrationQr ----
{
  const result = await call(getRegistrationQr, {
    params: { registrationId: confirmedRegistrationId }, user: student, collegeId,
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.qrToken, confirmedQrToken, 'should regenerate the exact same deterministic token');
  ok('getRegistrationQr regenerates the same QR token for a Confirmed registration');

  await Event.create({
    _id: 'event_paid', collegeId, title: 'Paid Workshop', eventType: 'Individual',
    teamMin: 1, teamMax: 1, paid: true, price: 200, maximumParticipants: 5, currentParticipants: 0,
    lifecycle: EventLifecycle.REGISTRATION_OPEN,
  });
  const pendingResult = await call(registerForEvent, { body: { eventId: 'event_paid' }, user: student, collegeId });
  const pendingRegId = pendingResult.body.data.registration._id;

  const qrForPending = await call(getRegistrationQr, {
    params: { registrationId: pendingRegId }, user: student, collegeId,
  });
  assert.equal(qrForPending.status, 409);
  assert.equal(qrForPending.body.details?.reason, 'NO_QR_AVAILABLE');
  ok('getRegistrationQr refuses to issue a QR for a Pending Payment registration');
}

// ---- validateQr: invalid / malformed ----
{
  const result = await call(validateQr, { body: { qrToken: 'garbage' }, user: organizer, collegeId });
  assert.equal(result.status, 400);
  assert.equal(result.body.details?.reason, 'INVALID_QR');
  ok('validateQr rejects a malformed QR token');

  const fakeButSignedForNothing = await call(validateQr, {
    body: { qrToken: 'nonexistent_id.deadbeef' }, user: organizer, collegeId,
  });
  assert.equal(fakeButSignedForNothing.status, 400);
  ok('validateQr rejects a QR token with an invalid signature');
}

// ---- validateQr: happy path (no attendance yet) ----
{
  const result = await call(validateQr, {
    body: { qrToken: confirmedQrToken, eventId: 'event_free' }, user: organizer, collegeId,
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.student.fullName, 'Asha Rao');
  assert.equal(result.body.data.attendance.checkedIn, false);
  ok('validateQr returns attendee info with no prior attendance record');
}

// ---- validateQr: wrong event ----
{
  await Event.create({
    _id: 'event_other', collegeId, title: 'Different Event', eventType: 'Individual',
    lifecycle: EventLifecycle.REGISTRATION_OPEN,
  });
  const result = await call(validateQr, {
    body: { qrToken: confirmedQrToken, eventId: 'event_other' }, user: organizer, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'WRONG_EVENT');
  ok('validateQr rejects a QR scanned at the wrong event\'s check-in desk');
}

// ---- check-in: happy path ----
{
  const result = await call(checkIn, {
    body: { qrToken: confirmedQrToken, eventId: 'event_free', scannerDevice: 'organizer-phone-1' },
    user: organizer, collegeId,
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.attendance.checkedIn, true);
  assert.equal(result.body.data.attendance.scannedBy, organizer._id);
  assert.equal(result.body.data.attendance.scannerDevice, 'organizer-phone-1');
  assert.equal(result.body.data.registration.status, 'Attended');
  ok('check-in succeeds and transitions the registration to Attended');
}

// ---- check-in: duplicate scan is rejected ----
{
  const result = await call(checkIn, {
    body: { qrToken: confirmedQrToken, eventId: 'event_free' }, user: organizer, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'ALREADY_CHECKED_IN');
  ok('Duplicate check-in scan is rejected with a clear reason code');
}

// ---- check-in: cancelled registration ----
{
  const cancelledReg = await Registration.create({
    _id: 'reg_cancelled', collegeId, eventId: 'event_free', studentId: student._id,
    qrTokenHash: buildQrToken('reg_cancelled').tokenHash, status: 'Cancelled',
  });
  const cancelledToken = buildQrToken(cancelledReg._id).token;
  const result = await call(checkIn, {
    body: { qrToken: cancelledToken, eventId: 'event_free' }, user: organizer, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'CANCELLED');
  ok('check-in rejects a cancelled registration');
}

// ---- check-in: pending payment registration ----
{
  const pendingReg = await Registration.create({
    _id: 'reg_pending', collegeId, eventId: 'event_paid', studentId: student._id,
    qrTokenHash: buildQrToken('reg_pending').tokenHash, status: 'Pending Payment',
  });
  const pendingToken = buildQrToken(pendingReg._id).token;
  const result = await call(checkIn, {
    body: { qrToken: pendingToken, eventId: 'event_paid' }, user: organizer, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'PAYMENT_PENDING');
  ok('check-in rejects a registration still awaiting payment');
}

// ---- check-in: event ended/cancelled ----
{
  await Event.create({
    _id: 'event_archived', collegeId, title: 'Old Event', eventType: 'Individual',
    lifecycle: EventLifecycle.ARCHIVED,
  });
  const endedReg = await Registration.create({
    _id: 'reg_ended', collegeId, eventId: 'event_archived', studentId: student._id,
    qrTokenHash: buildQrToken('reg_ended').tokenHash, status: 'Confirmed',
  });
  const endedToken = buildQrToken(endedReg._id).token;
  const result = await call(checkIn, {
    body: { qrToken: endedToken, eventId: 'event_archived' }, user: organizer, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'EVENT_ENDED');
  ok('check-in rejects an archived/ended event');
}

// ---- check-out: must be checked in first ----
{
  await Event.create({
    _id: 'event_checkout_test', collegeId, title: 'Checkout Test Event', eventType: 'Individual',
    lifecycle: EventLifecycle.REGISTRATION_OPEN,
  });
  const reg = await Registration.create({
    _id: 'reg_checkout', collegeId, eventId: 'event_checkout_test', studentId: student._id,
    qrTokenHash: buildQrToken('reg_checkout').tokenHash, status: 'Confirmed',
  });
  const token = buildQrToken(reg._id).token;

  const tooEarly = await call(checkOut, {
    body: { qrToken: token, eventId: 'event_checkout_test' }, user: organizer, collegeId,
  });
  assert.equal(tooEarly.status, 409);
  assert.equal(tooEarly.body.details?.reason, 'NOT_CHECKED_IN');
  ok('check-out rejects an attendee who was never checked in');

  const checkinResult = await call(checkIn, {
    body: { qrToken: token, eventId: 'event_checkout_test' }, user: organizer, collegeId,
  });
  assert.equal(checkinResult.status, 200);

  const checkoutResult = await call(checkOut, {
    body: { qrToken: token, eventId: 'event_checkout_test' }, user: organizer, collegeId,
  });
  assert.equal(checkoutResult.status, 200);
  assert.equal(checkoutResult.body.data.attendance.checkedOut, true);
  ok('check-out succeeds after a valid check-in');

  const duplicateCheckout = await call(checkOut, {
    body: { qrToken: token, eventId: 'event_checkout_test' }, user: organizer, collegeId,
  });
  assert.equal(duplicateCheckout.status, 409);
  assert.equal(duplicateCheckout.body.details?.reason, 'ALREADY_CHECKED_OUT');
  ok('Duplicate check-out scan is rejected with a clear reason code');
}

console.log(`\n${passed} checks passed.`);
