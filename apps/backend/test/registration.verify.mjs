// Verification harness for the Registration milestone.
//
// This sandbox has no MongoDB and no network access to fetch one, so this
// script exercises the REAL controller functions against lightweight
// in-memory fakes of the Mongoose model methods actually used
// (find/findOne/findOneAndUpdate/findByIdAndUpdate/findByIdAndDelete/create/save).
// The fakes implement just enough query-matching ($ne, $expr with $or/$eq/$lt)
// to support the exact queries this controller issues. Business logic
// (capacity checks, duplicate prevention, team size validation, cancellation
// bookkeeping) runs unmodified from registration.controller.js.
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
    if (value && typeof value === 'object' && '$ne' in value) {
      if (String(doc[key]) === String(value.$ne)) return false;
      continue;
    }
    if (String(doc[key]) !== String(value)) return false;
  }
  return true;
}
function applyUpdate(doc, update) {
  if (update.$inc) {
    for (const [k, v] of Object.entries(update.$inc)) doc[k] = (doc[k] ?? 0) + v;
  }
  for (const [k, v] of Object.entries(update)) {
    if (k !== '$inc') doc[k] = v;
  }
}

let seq = 1;
function makeFakeModel() {
  const store = new Map();
  const withSave = (doc) => {
    if (!doc.save) doc.save = async function () { store.set(this._id, { ...this }); return this; };
    return doc;
  };
  const chain = (results) => ({
    populate: () => chain(results),
    sort: () => chain(results),
    skip: () => chain(results),
    limit: () => chain(results),
    then: (resolve, reject) => Promise.resolve(results).then(resolve, reject),
  });
  return {
    store,
    async create(docOrDocs) {
      const arr = Array.isArray(docOrDocs) ? docOrDocs : [docOrDocs];
      const created = arr.map((d) => {
        const _id = d._id || `id_${seq++}`;
        const doc = withSave({ ...d, _id });
        store.set(_id, doc);
        return doc;
      });
      return Array.isArray(docOrDocs) ? created : created[0];
    },
    async findOne(query) {
      for (const doc of store.values()) if (matches(doc, query)) return withSave(doc);
      return null;
    },
    async findById(id) {
      const doc = store.get(id);
      return doc ? withSave(doc) : null;
    },
    async findByIdAndUpdate(id, update) {
      const doc = store.get(id);
      if (!doc) return null;
      applyUpdate(doc, update);
      return withSave(doc);
    },
    async findByIdAndDelete(id) {
      const doc = store.get(id) ?? null;
      store.delete(id);
      return doc;
    },
    async findOneAndUpdate(query, update) {
      for (const doc of store.values()) {
        if (matches(doc, query)) {
          applyUpdate(doc, update);
          return withSave(doc);
        }
      }
      return null;
    },
    find(query) {
      return chain([...store.values()].filter((d) => matches(d, query)));
    },
  };
}

// --- Wire the fakes into the real model modules before the controller
// module (which imports them) is loaded. ---
const { Registration } = await import('../src/modules/registrations/registration.model.js');
const { Team, TeamMember } = await import('../src/modules/teams/team.model.js');
const { Event, EventLifecycle } = await import('../src/modules/events/event.model.js');

Object.assign(Registration, makeFakeModel());
Object.assign(Team, makeFakeModel());
Object.assign(TeamMember, makeFakeModel());
const fakeEventModel = makeFakeModel();
Object.assign(Event, fakeEventModel);

const {
  registerForEvent,
  listMyRegistrations,
  listEventRegistrations,
  cancelRegistration,
} = await import('../src/modules/registrations/registration.controller.js');

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
const studentA = { _id: 'user_A', collegeId, fullName: 'Asha Rao', phone: '+919000000001', rollNumber: 'VU1', status: 'Active' };
const studentB = { _id: 'user_B', collegeId, fullName: 'Bala Singh', phone: '+919000000002', rollNumber: 'VU2', status: 'Active' };

let passed = 0;
function ok(label) { passed++; console.log(`  ✔ ${label}`); }

console.log('Registration milestone — mock-backed controller verification\n');

// ---- Individual event: happy path ----
{
  await Event.create({
    _id: 'event_individual',
    collegeId,
    title: 'Hack Night',
    eventType: 'Individual',
    teamMin: 1,
    teamMax: 1,
    paid: false,
    maximumParticipants: 2,
    currentParticipants: 0,
    lifecycle: EventLifecycle.REGISTRATION_OPEN,
  });

  const req = { body: { eventId: 'event_individual' }, user: studentA, collegeId };
  const result = await call(registerForEvent, req);
  assert.equal(result.status, 201, 'individual registration should succeed');
  assert.equal(result.body.data.registration.status, 'Confirmed');
  assert.ok(result.body.data.qrToken?.length > 0, 'qr token should be issued');
  ok('Individual registration succeeds and issues a QR token');

  const event = await Event.findById('event_individual');
  assert.equal(event.currentParticipants, 1, 'capacity should increment');
  ok('Event capacity increments on confirmed registration');
}

// ---- Duplicate registration prevention ----
{
  const req = { body: { eventId: 'event_individual' }, user: studentA, collegeId };
  const result = await call(registerForEvent, req);
  assert.equal(result.status, 409);
  assert.match(result.body.message, /already registered/i);
  ok('Duplicate registration is rejected with 409');
}

// ---- Capacity validation ----
{
  const req = { body: { eventId: 'event_individual' }, user: studentB, collegeId };
  const result = await call(registerForEvent, req);
  assert.equal(result.status, 201, 'second distinct student should fill last slot');
  ok('Second student fills the last capacity slot');

  const full = await Event.findById('event_individual');
  assert.equal(full.currentParticipants, 2);

  const studentC = { _id: 'user_C', collegeId, fullName: 'Chetan Iyer', phone: '+919000000003', status: 'Active' };
  const overflowReq = { body: { eventId: 'event_individual' }, user: studentC, collegeId };
  const overflowResult = await call(registerForEvent, overflowReq);
  assert.equal(overflowResult.status, 409);
  assert.match(overflowResult.body.message, /maximum number of participants/i);
  ok('Registration is rejected once event reaches maximum capacity');
}

// ---- Team event: size validation ----
{
  await Event.create({
    _id: 'event_team',
    collegeId,
    title: 'Robo Rumble',
    eventType: 'Team',
    teamMin: 2,
    teamMax: 4,
    paid: false,
    maximumParticipants: null,
    currentParticipants: 0,
    lifecycle: EventLifecycle.REGISTRATION_OPEN,
  });

  const tooSmall = await call(registerForEvent, {
    body: { eventId: 'event_team', teamName: 'Solo Squad', members: [] },
    user: studentA,
    collegeId,
  });
  assert.equal(tooSmall.status, 422);
  assert.match(tooSmall.body.message, /team size must be between/i);
  ok('Team below minimum size is rejected with 422');

  const tooBig = await call(registerForEvent, {
    body: {
      eventId: 'event_team',
      teamName: 'Mega Squad',
      members: [
        { fullName: 'M1', phone: '1' }, { fullName: 'M2', phone: '2' },
        { fullName: 'M3', phone: '3' }, { fullName: 'M4', phone: '4' },
      ],
    },
    user: studentA,
    collegeId,
  });
  assert.equal(tooBig.status, 422);
  ok('Team above maximum size is rejected with 422');
}

// ---- Team event: happy path ----
{
  const req = {
    body: {
      eventId: 'event_team',
      teamName: 'Circuit Breakers',
      members: [{ fullName: 'Meera Nair', phone: '+919000000009', rollNumber: 'VU9' }],
    },
    user: studentA,
    collegeId,
  };
  const result = await call(registerForEvent, req);
  assert.equal(result.status, 201);
  assert.ok(result.body.data.registration.teamId, 'registration should reference a team');
  ok('Team registration succeeds with a valid team size');

  const teamMembers = [...TeamMember.store.values()].filter((m) => m.teamId === result.body.data.registration.teamId);
  assert.equal(teamMembers.length, 2, 'leader + 1 member should be recorded');
  assert.equal(teamMembers.find((m) => m.role === 'Leader').userId, studentA._id);
  ok('Team members (leader + member) are recorded correctly');
}

// ---- listMyRegistrations / listEventRegistrations ----
{
  const mine = await call(listMyRegistrations, { user: studentA, collegeId });
  assert.equal(mine.status, 200);
  assert.equal(mine.body.data.length, 2, 'studentA has 2 registrations (individual + team)');
  ok('listMyRegistrations returns the correct registrations for the current user');

  const forEvent = await call(listEventRegistrations, { params: { eventId: 'event_individual' }, collegeId });
  assert.equal(forEvent.status, 200);
  assert.equal(forEvent.body.data.length, 2);
  ok('listEventRegistrations returns all registrations for an event');
}

// ---- Cancellation ----
{
  const mine = await call(listMyRegistrations, { user: studentA, collegeId });
  const individualRegistration = mine.body.data.find((r) => r.eventId === 'event_individual' || r.eventId?._id === 'event_individual');

  const cancelResult = await call(cancelRegistration, {
    params: { registrationId: individualRegistration._id },
    user: studentA,
    collegeId,
  });
  assert.equal(cancelResult.status, 200);
  assert.equal(cancelResult.body.data.status, 'Cancelled');
  ok('Cancelling a confirmed registration succeeds');

  const eventAfterCancel = await Event.findById('event_individual');
  assert.equal(eventAfterCancel.currentParticipants, 1, 'capacity should decrement on cancellation');
  ok('Event capacity decrements when a confirmed registration is cancelled');

  const doubleCancel = await call(cancelRegistration, {
    params: { registrationId: individualRegistration._id },
    user: studentA,
    collegeId,
  });
  assert.equal(doubleCancel.status, 409);
  ok('Cancelling an already-cancelled registration is rejected with 409');

  // The cancelled slot should now be available again for a new student.
  const studentD = { _id: 'user_D', collegeId, fullName: 'Divya Menon', phone: '+919000000004', status: 'Active' };
  const refill = await call(registerForEvent, { body: { eventId: 'event_individual' }, user: studentD, collegeId });
  assert.equal(refill.status, 201, 'cancelled slot should be available again');
  ok('A cancelled slot can be re-filled by another student');
}

// ---- Paid event: no capacity consumed until payment (future milestone) ----
{
  await Event.create({
    _id: 'event_paid',
    collegeId,
    title: 'Paid Workshop',
    eventType: 'Individual',
    teamMin: 1,
    teamMax: 1,
    paid: true,
    maximumParticipants: 1,
    currentParticipants: 0,
    lifecycle: EventLifecycle.REGISTRATION_OPEN,
  });
  const result = await call(registerForEvent, { body: { eventId: 'event_paid' }, user: studentA, collegeId });
  assert.equal(result.status, 201);
  assert.equal(result.body.data.registration.status, 'Pending Payment');
  const event = await Event.findById('event_paid');
  assert.equal(event.currentParticipants, 0, 'paid registrations should not consume capacity yet');
  ok('Paid event registration is created as Pending Payment without consuming capacity');
}

console.log(`\n${passed} checks passed.`);
