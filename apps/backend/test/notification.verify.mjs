// Verification harness for the Notifications milestone. Same approach as
// prior milestones: no MongoDB in this sandbox, so this mocks only the
// Mongoose model methods used, and runs the real, unmodified service/
// controller functions against them. Crucially, `sendPushNotification`
// is NOT mocked here — there are no real Firebase Admin credentials in
// this test process, so it genuinely exercises the real mock-provider
// fallback code path (not a test double standing in for it).
import assert from 'node:assert/strict';

function matches(doc, query) {
  for (const [key, value] of Object.entries(query)) {
    if (value && typeof value === 'object' && '$ne' in value) {
      if (String(doc[key]) === String(value.$ne)) return false;
      continue;
    }
    if (value && typeof value === 'object' && '$in' in value) {
      if (!value.$in.map(String).includes(String(doc[key]))) return false;
      continue;
    }
    if (value === null) {
      if (doc[key] !== null && doc[key] !== undefined) return false;
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
  const chain = (results) => {
    let items = results;
    const api = {
      populate: () => api,
      sort: () => api,
      select: () => api,
      skip: (n) => { items = items.slice(n); return api; },
      limit: (n) => { items = items.slice(0, n); return api; },
      then: (resolve, reject) => Promise.resolve(items).then(resolve, reject),
      distinct: (field) => {
        const values = [...new Set(items.map((d) => d[field]).filter((v) => v !== undefined))];
        return Promise.resolve(values);
      },
    };
    return api;
  };
  return {
    store,
    async create(doc) {
      const _id = doc._id || `id_${seq++}`;
      const created = withHelpers({ ...doc, _id });
      store.set(_id.toString(), created);
      return created;
    },
    async insertMany(docs) {
      return Promise.all(docs.map((d) => this.create(d)));
    },
    findOne(query) {
      const found = [...store.values()].find((doc) => matches(doc, query));
      return Promise.resolve(found ? withHelpers(found) : null);
    },
    async findById(id) {
      const doc = store.get(id?.toString());
      return doc ? withHelpers(doc) : null;
    },
    find(query = {}) {
      return chain([...store.values()].filter((d) => matches(d, query)).map(withHelpers));
    },
    async countDocuments(query = {}) {
      return [...store.values()].filter((d) => matches(d, query)).length;
    },
    async updateMany(query, update) {
      const docs = [...store.values()].filter((d) => matches(d, query));
      for (const doc of docs) {
        if (update.$set) Object.assign(doc, update.$set);
      }
      return { modifiedCount: docs.length };
    },
  };
}

const { Notification, NotificationRecipient } = await import(
  '../src/modules/notifications/notification.model.js'
);
const { User } = await import('../src/modules/users/user.model.js');
const { Club } = await import('../src/modules/clubs/club.model.js');
const { Event } = await import('../src/modules/events/event.model.js');
const { Registration } = await import('../src/modules/registrations/registration.model.js');

Object.assign(Notification, makeFakeModel());
Object.assign(NotificationRecipient, makeFakeModel());
Object.assign(User, makeFakeModel());
Object.assign(Club, makeFakeModel());
Object.assign(Event, makeFakeModel());
Object.assign(Registration, makeFakeModel());

const {
  resolveAudienceUserIds,
  sendNotification,
  listNotificationHistory,
  listMyNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  deleteMyNotification,
} = await import('../src/modules/notifications/notification.service.js');
const {
  createNotification,
  getNotificationHistory,
  getMyNotifications,
  readNotification,
  readAllNotifications,
  removeMyNotification,
} = await import('../src/modules/notifications/notification.controller.js');

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
const admin = { _id: 'user_admin', collegeId, role: 'Admin' };

let passed = 0;
function ok(label) { passed++; console.log(`  ✔ ${label}`); }

console.log('Notifications milestone — mock-backed controller verification\n');

// Seed students across branches/years, one club with an event, and
// registrations (including a cancelled one, which must be excluded).
await User.create({ _id: 's1', collegeId, role: 'Student', status: 'Active', branch: 'CS', year: 1, fcmTokens: ['tok1', 'tok2'] });
await User.create({ _id: 's2', collegeId, role: 'Student', status: 'Active', branch: 'CS', year: 2, fcmTokens: ['tok3'] });
await User.create({ _id: 's3', collegeId, role: 'Student', status: 'Active', branch: 'IT', year: 1, fcmTokens: [] });
await User.create({ _id: 's4', collegeId, role: 'Student', status: 'Suspended', branch: 'CS', year: 1, fcmTokens: ['tok4'] });
await Club.create({ _id: 'club_1', collegeId, name: 'Coding Club', category: 'Tech' });
await Event.create({ _id: 'event_1', collegeId, clubId: 'club_1', title: 'Hackathon' });
await Registration.create({ _id: 'reg_1', collegeId, eventId: 'event_1', studentId: 's1', status: 'Confirmed', qrTokenHash: 'h1' });
await Registration.create({ _id: 'reg_2', collegeId, eventId: 'event_1', studentId: 's2', status: 'Attended', qrTokenHash: 'h2' });
await Registration.create({ _id: 'reg_3', collegeId, eventId: 'event_1', studentId: 's3', status: 'Cancelled', qrTokenHash: 'h3' });

// ---- resolveAudienceUserIds ----
{
  const college = await resolveAudienceUserIds({ collegeId, audience: { type: 'College' } });
  assert.deepEqual(new Set(college), new Set(['s1', 's2', 's3']), 'only Active students, not Suspended s4');
  ok('College audience resolves to all Active students');

  const branch = await resolveAudienceUserIds({ collegeId, audience: { type: 'Branch', branch: 'CS' } });
  assert.deepEqual(new Set(branch), new Set(['s1', 's2']));
  ok('Branch audience filters correctly');

  const year = await resolveAudienceUserIds({ collegeId, audience: { type: 'Year', year: 1 } });
  assert.deepEqual(new Set(year), new Set(['s1', 's3']));
  ok('Year audience filters correctly');

  const club = await resolveAudienceUserIds({ collegeId, audience: { type: 'Club', clubId: 'club_1' } });
  assert.deepEqual(new Set(club), new Set(['s1', 's2']), 'excludes the cancelled registrant s3');
  ok('Club audience resolves via the club\'s events\' non-cancelled registrants');

  const eventAudience = await resolveAudienceUserIds({ collegeId, audience: { type: 'Event Participants', eventId: 'event_1' } });
  assert.deepEqual(new Set(eventAudience), new Set(['s1', 's2']));
  ok('Event Participants audience excludes cancelled registrations');

  const individual = await resolveAudienceUserIds({ collegeId, audience: { type: 'Individual Student', userId: 's3' } });
  assert.deepEqual(individual, ['s3']);
  ok('Individual Student audience resolves to exactly that user');
}

// ---- Validation ----
{
  await assert.rejects(
    resolveAudienceUserIds({ collegeId, audience: { type: 'NotAType' } }),
    /audience.type must be one of/
  );
  ok('Invalid audience.type is rejected');

  await assert.rejects(resolveAudienceUserIds({ collegeId, audience: { type: 'Branch' } }), /audience.branch is required/);
  await assert.rejects(resolveAudienceUserIds({ collegeId, audience: { type: 'Year' } }), /audience.year is required/);
  await assert.rejects(resolveAudienceUserIds({ collegeId, audience: { type: 'Club' } }), /audience.clubId is required/);
  await assert.rejects(resolveAudienceUserIds({ collegeId, audience: { type: 'Event Participants' } }), /audience.eventId is required/);
  await assert.rejects(resolveAudienceUserIds({ collegeId, audience: { type: 'Individual Student' } }), /audience.userId is required/);
  ok('Every audience type validates its required field');

  await assert.rejects(
    resolveAudienceUserIds({ collegeId, audience: { type: 'Club', clubId: 'does-not-exist' } }),
    /does not reference a valid club/
  );
  ok('A non-existent clubId is rejected');
}

// ---- sendNotification: happy path + mock push provider ----
let sentRecipientCount;
{
  const result = await call(createNotification, {
    body: { title: 'Fest Reminder', body: 'Don\'t miss the fest!', audience: { type: 'Branch', branch: 'CS' } },
    user: admin, collegeId,
  });
  assert.equal(result.status, 201);
  assert.equal(result.body.data.recipientCount, 2);
  assert.equal(result.body.data.notification.status, 'Sent');
  sentRecipientCount = result.body.data.recipientCount;
  ok('sendNotification creates the broadcast and resolves the correct recipient count');

  // No real Firebase Admin credentials exist in this test process, so
  // this genuinely exercises the mock push provider, not a stand-in.
  assert.equal(result.body.data.push.mocked, true);
  assert.equal(result.body.data.push.attempted, true);
  assert.equal(result.body.data.push.successCount, 3, 's1 has 2 tokens + s2 has 1 token = 3');
  ok('The real mock push provider is exercised and reports the correct token count');

  const recipientRows = await NotificationRecipient.find({ collegeId, notificationId: result.body.data.notification._id });
  assert.equal((await recipientRows).length, sentRecipientCount);
  ok('One NotificationRecipient row is created per matched student');
}

// ---- sendNotification: validation ----
{
  const missingTitle = await call(createNotification, {
    body: { body: 'x', audience: { type: 'College' } }, user: admin, collegeId,
  });
  assert.equal(missingTitle.status, 400);
  ok('sendNotification rejects a missing title');

  const noRecipients = await call(createNotification, {
    body: { title: 'x', body: 'y', audience: { type: 'Individual Student', userId: 'does-not-exist' } },
    user: admin, collegeId,
  });
  assert.equal(noRecipients.status, 422);
  ok('sendNotification rejects a reference to a non-existent individual student');

  await User.create({ _id: 's5', collegeId, role: 'Student', status: 'Active', branch: 'Mech', year: 3, fcmTokens: [] });
  const zeroTokens = await call(createNotification, {
    body: { title: 'x', body: 'y', audience: { type: 'Individual Student', userId: 's5' } },
    user: admin, collegeId,
  });
  assert.equal(zeroTokens.status, 201);
  assert.equal(zeroTokens.body.data.push.attempted, false, 'no push attempt when the recipient has no device tokens');
  ok('sendNotification succeeds (in-app) even when the recipient has no FCM tokens registered');
}

// ---- listMyNotifications + unreadCount ----
{
  const result = await call(getMyNotifications, { query: {}, user: { _id: 's1', collegeId }, collegeId });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.items.length, 1);
  assert.equal(result.body.data.unreadCount, 1);
  ok('listMyNotifications returns the student\'s inbox with an accurate unread count');
}

// ---- markNotificationRead ----
let s1RecipientId;
{
  const inbox = await call(getMyNotifications, { query: {}, user: { _id: 's1', collegeId }, collegeId });
  s1RecipientId = inbox.body.data.items[0]._id;

  const result = await call(readNotification, {
    params: { recipientId: s1RecipientId }, user: { _id: 's1', collegeId }, collegeId,
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.isRead, true);
  ok('markNotificationRead marks a single notification as read');

  const afterRead = await call(getMyNotifications, { query: {}, user: { _id: 's1', collegeId }, collegeId });
  assert.equal(afterRead.body.data.unreadCount, 0);
  ok('unreadCount reflects the read status afterward');

  const wrongOwner = await call(readNotification, {
    params: { recipientId: s1RecipientId }, user: { _id: 's2', collegeId }, collegeId,
  });
  assert.equal(wrongOwner.status, 404);
  ok('A different student cannot mark someone else\'s notification as read');
}

// ---- markAllNotificationsRead ----
{
  const result = await call(readAllNotifications, { user: { _id: 's2', collegeId }, collegeId });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.updatedCount, 1);
  const afterAll = await call(getMyNotifications, { query: {}, user: { _id: 's2', collegeId }, collegeId });
  assert.equal(afterAll.body.data.unreadCount, 0);
  ok('markAllNotificationsRead clears every unread notification for that student');
}

// ---- deleteMyNotification (soft delete) ----
{
  const before = await call(getMyNotifications, { query: {}, user: { _id: 's1', collegeId }, collegeId });
  assert.equal(before.body.data.items.length, 1);

  const result = await call(removeMyNotification, {
    params: { recipientId: s1RecipientId }, user: { _id: 's1', collegeId }, collegeId,
  });
  assert.equal(result.status, 200);
  ok('deleteMyNotification succeeds');

  const after = await call(getMyNotifications, { query: {}, user: { _id: 's1', collegeId }, collegeId });
  assert.equal(after.body.data.items.length, 0);
  ok('Deleted notification no longer appears in the student\'s inbox');

  const doubleDelete = await call(removeMyNotification, {
    params: { recipientId: s1RecipientId }, user: { _id: 's1', collegeId }, collegeId,
  });
  assert.equal(doubleDelete.status, 404);
  ok('Deleting an already-deleted notification returns 404, not a silent success');
}

// ---- Admin notification history + pagination ----
{
  const result = await call(getNotificationHistory, { query: {}, user: admin, collegeId });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.total, 2, 'Branch CS send + individual s5 send = 2 (the missing-title and no-such-user attempts were rejected before creating a Notification)');
  ok('getNotificationHistory returns the college\'s full broadcast history with a total count');

  const paged = await call(getNotificationHistory, { query: { page: 1, limit: 1 }, user: admin, collegeId });
  assert.equal(paged.body.data.items.length, 1);
  assert.equal(paged.body.data.limit, 1);
  ok('getNotificationHistory respects pagination parameters');
}

console.log(`\n${passed} checks passed.`);
