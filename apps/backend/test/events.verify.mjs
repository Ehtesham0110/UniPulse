// Verification harness for the Events milestone. Same approach as
// registration.verify.mjs: no MongoDB is available in this sandbox, so
// this mocks only the Mongoose model methods actually used, and runs the
// real, unmodified controller functions against them.
import assert from 'node:assert/strict';

function matches(doc, query) {
  for (const [key, value] of Object.entries(query)) {
    if (key === '$or') {
      if (!value.some((clause) => matches(doc, clause))) return false;
      continue;
    }
    if (value && typeof value === 'object' && '$in' in value) {
      const set = value.$in.map(String);
      if (!set.includes(String(doc[key]))) return false;
      continue;
    }
    if (value instanceof RegExp) {
      if (!value.test(doc[key] ?? '')) return false;
      continue;
    }
    if (value && typeof value === 'object' && ('$gte' in value || '$lte' in value)) {
      const docVal = doc[key] instanceof Date ? doc[key] : new Date(doc[key]);
      if (value.$gte && docVal < value.$gte) return false;
      if (value.$lte && docVal > value.$lte) return false;
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
    if (!doc.save) {
      doc.save = async function () { store.set(this._id, this); return this; };
    }
    if (!doc.toObject) {
      doc.toObject = function () { const { save, toObject, ...rest } = this; return { ...rest }; };
    }
    return doc;
  };
  const chain = (results) => {
    let items = results;
    const api = {
      sort: () => api,
      skip: (n) => { items = items.slice(n); return api; },
      limit: (n) => { items = items.slice(0, n); return api; },
      then: (resolve, reject) => Promise.resolve(items).then(resolve, reject),
    };
    return api;
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
    async deleteOne(query) {
      for (const [id, doc] of store.entries()) {
        if (matches(doc, query)) { store.delete(id); return { deletedCount: 1 }; }
      }
      return { deletedCount: 0 };
    },
    find(query) {
      return chain([...store.values()].filter((d) => matches(d, query)));
    },
  };
}

const { Event, EventLifecycle } = await import('../src/modules/events/event.model.js');
const { Club } = await import('../src/modules/clubs/club.model.js');
Object.assign(Event, makeFakeModel());
Object.assign(Club, makeFakeModel());

const {
  listEvents,
  getEvent,
  createEvent,
  updateEvent,
  deleteEvent,
  toggleBookmark,
} = await import('../src/modules/events/event.controller.js');

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
const student = { _id: 'user_student', collegeId, role: 'Student', bookmarks: [], save: async function () {} };
const organizer = { _id: 'user_organizer', collegeId, role: 'Organizer', bookmarks: [], save: async function () {} };
const admin = { _id: 'user_admin', collegeId, role: 'Admin', bookmarks: [], save: async function () {} };

let passed = 0;
function ok(label) { passed++; console.log(`  ✔ ${label}`); }

console.log('Events milestone — mock-backed controller verification\n');

await Club.create({ _id: 'club_1', collegeId, name: 'Coding Club', category: 'Tech' });

// ---- createEvent: validation ----
{
  const missingFields = await call(createEvent, { body: {}, user: organizer, collegeId });
  assert.equal(missingFields.status, 422);
  ok('createEvent rejects an empty payload with 422');

  const badClub = await call(createEvent, {
    body: {
      title: 'Hack Night', description: 'desc', venue: 'Hall', clubId: 'does-not-exist',
      eventDate: '2026-08-01', eventType: 'Individual', category: 'Tech',
    },
    user: organizer, collegeId,
  });
  assert.equal(badClub.status, 422);
  assert.match(badClub.body.message, /clubId/);
  ok('createEvent rejects a clubId that does not belong to the college');

  const badTeamSize = await call(createEvent, {
    body: {
      title: 'Robo Rumble', description: 'desc', venue: 'Lab', clubId: 'club_1',
      eventDate: '2026-08-01', eventType: 'Team', teamMin: 4, teamMax: 2, category: 'Tech',
    },
    user: organizer, collegeId,
  });
  assert.equal(badTeamSize.status, 422);
  ok('createEvent rejects teamMax < teamMin');

  const badPaid = await call(createEvent, {
    body: {
      title: 'Paid Workshop', description: 'desc', venue: 'Hall', clubId: 'club_1',
      eventDate: '2026-08-01', eventType: 'Individual', category: 'Tech', paid: true, price: 0,
    },
    user: organizer, collegeId,
  });
  assert.equal(badPaid.status, 422);
  ok('createEvent rejects a paid event with price 0');
}

// ---- createEvent: happy path + duplicate title slug uniqueness ----
let publishedEventId;
{
  const first = await call(createEvent, {
    body: {
      title: 'Hackathon 3.0', description: 'Build cool things', venue: 'Seminar Hall', clubId: 'club_1',
      eventDate: '2026-08-01', eventType: 'Team', teamMin: 2, teamMax: 4, category: 'Tech',
      requiresApproval: false,
    },
    user: organizer, collegeId,
  });
  assert.equal(first.status, 201);
  assert.equal(first.body.data.lifecycle, 'Draft');
  publishedEventId = first.body.data._id;
  await Event.findById(publishedEventId).then((e) => { e.lifecycle = EventLifecycle.REGISTRATION_OPEN; });
  ok('createEvent succeeds with a valid payload (Draft when requiresApproval: false)');

  const second = await call(createEvent, {
    body: {
      title: 'Hackathon 3.0', description: 'Another one', venue: 'Lab', clubId: 'club_1',
      eventDate: '2026-09-01', eventType: 'Individual', category: 'Tech', requiresApproval: false,
    },
    user: organizer, collegeId,
  });
  assert.equal(second.status, 201, 'duplicate titles should not crash on a unique-slug collision');
  assert.notEqual(second.body.data.slug, first.body.data.slug);
  ok('Two events with the same title get distinct slugs instead of crashing');
}

// ---- listEvents: default visibility hides Draft/Pending from students ----
{
  await Event.create({
    _id: 'event_draft', collegeId, title: 'Secret Draft', description: 'shh', category: 'Tech',
    venue: 'TBA', eventDate: new Date('2026-08-05'), eventType: 'Individual', clubId: 'club_1',
    createdBy: organizer._id, lifecycle: EventLifecycle.DRAFT,
  });

  const asStudent = await call(listEvents, { query: {}, user: student, collegeId });
  assert.equal(asStudent.status, 200);
  assert.ok(!asStudent.body.data.some((e) => e._id === 'event_draft'), 'student should not see Draft events');
  ok('listEvents hides Draft events from students by default');

  const asOrganizer = await call(listEvents, { query: {}, user: organizer, collegeId });
  assert.ok(asOrganizer.body.data.some((e) => e._id === 'event_draft'), 'organizer should see their Draft events');
  ok('listEvents shows Draft events to organizers/admins by default');
}

// ---- listEvents: category filter + search ----
{
  await Event.create({
    _id: 'event_nontech', collegeId, title: 'Treasure Hunt', description: 'Find the clues',
    category: 'Non Tech', venue: 'Campus', eventDate: new Date('2026-08-10'),
    eventType: 'Individual', clubId: 'club_1', createdBy: organizer._id,
    lifecycle: EventLifecycle.REGISTRATION_OPEN,
  });

  const techOnly = await call(listEvents, { query: { category: 'Tech' }, user: student, collegeId });
  assert.ok(techOnly.body.data.every((e) => e.category === 'Tech'));
  ok('listEvents filters by category');

  const searchResult = await call(listEvents, { query: { search: 'treasure' }, user: student, collegeId });
  assert.equal(searchResult.body.data.length, 1);
  assert.equal(searchResult.body.data[0]._id, 'event_nontech');
  ok('listEvents search matches title case-insensitively');

  const invalidCategory = await call(listEvents, { query: { category: 'Sports' }, user: student, collegeId });
  assert.equal(invalidCategory.status, 422);
  ok('listEvents rejects an invalid category with 422');
}

// ---- getEvent: visibility + isBookmarked ----
{
  const hidden = await call(getEvent, { params: { eventId: 'event_draft' }, user: student, collegeId });
  assert.equal(hidden.status, 404, 'students should not be able to fetch a Draft event directly either');
  ok('getEvent hides Draft events from students (404, not 403)');

  const visible = await call(getEvent, { params: { eventId: 'event_nontech' }, user: student, collegeId });
  assert.equal(visible.status, 200);
  assert.equal(visible.body.data.isBookmarked, false);
  ok('getEvent returns isBookmarked: false when not bookmarked');
}

// ---- toggleBookmark ----
{
  const bookmarked = await call(toggleBookmark, { params: { eventId: 'event_nontech' }, user: student, collegeId });
  assert.equal(bookmarked.status, 200);
  assert.equal(bookmarked.body.data.isBookmarked, true);
  ok('toggleBookmark bookmarks an event');

  const fetched = await call(getEvent, { params: { eventId: 'event_nontech' }, user: student, collegeId });
  assert.equal(fetched.body.data.isBookmarked, true);
  ok('getEvent reflects the bookmark after toggling');

  const unbookmarked = await call(toggleBookmark, { params: { eventId: 'event_nontech' }, user: student, collegeId });
  assert.equal(unbookmarked.body.data.isBookmarked, false);
  ok('toggleBookmark un-bookmarks on a second call');
}

// ---- listEvents: startDate / endDate range query ----
{
  const rangeQuery = await call(listEvents, {
    query: { startDate: '2026-07-01', endDate: '2026-07-31' },
    user: student,
    collegeId,
  });
  assert.equal(rangeQuery.status, 200);
  assert.ok(Array.isArray(rangeQuery.body.data));
  assert.ok(rangeQuery.body.data.every((e) => new Date(e.eventDate) >= new Date('2026-07-01') && new Date(e.eventDate) <= new Date('2026-07-31')));
  ok('listEvents filters events correctly by startDate and endDate range');
}

// ---- updateEvent: permissions + validation ----
{
  const asStudentDenied = await call(updateEvent, {
    params: { eventId: 'event_nontech' }, body: { title: 'Hacked' }, user: student, collegeId,
  });
  assert.equal(asStudentDenied.status, 403);
  ok('updateEvent rejects a student with 403');

  const asOwner = await call(updateEvent, {
    params: { eventId: 'event_nontech' }, body: { venue: 'New Venue' }, user: organizer, collegeId,
  });
  assert.equal(asOwner.status, 200);
  assert.equal(asOwner.body.data.venue, 'New Venue');
  ok('updateEvent allows the organizer who created the event');

  const invalidUpdate = await call(updateEvent, {
    params: { eventId: 'event_nontech' }, body: { category: 'Sports' }, user: organizer, collegeId,
  });
  assert.equal(invalidUpdate.status, 422);
  ok('updateEvent validates fields on partial updates too');

  const asAdmin = await call(updateEvent, {
    params: { eventId: 'event_nontech' }, body: { venue: 'Admin Override Hall' }, user: admin, collegeId,
  });
  assert.equal(asAdmin.status, 200);
  ok('updateEvent allows Admin regardless of ownership');
}

// ---- deleteEvent: guarded by existing registrations ----
{
  await Event.create({
    _id: 'event_with_regs', collegeId, title: 'Full Event', description: 'd', category: 'Tech',
    venue: 'Hall', eventDate: new Date('2026-08-15'), eventType: 'Individual', clubId: 'club_1',
    createdBy: organizer._id, lifecycle: EventLifecycle.REGISTRATION_OPEN, currentParticipants: 3,
  });

  const blocked = await call(deleteEvent, { params: { eventId: 'event_with_regs' }, user: admin, collegeId });
  assert.equal(blocked.status, 409);
  ok('deleteEvent refuses to delete an event that already has registrations');

  const deleted = await call(deleteEvent, { params: { eventId: 'event_nontech' }, user: admin, collegeId });
  assert.equal(deleted.status, 200);
  assert.equal(deleted.body.data.deleted, true);
  ok('deleteEvent succeeds for an event with no registrations');

  const goneNow = await call(getEvent, { params: { eventId: 'event_nontech' }, user: admin, collegeId });
  assert.equal(goneNow.status, 404);
  ok('Deleted event is actually gone');
}

console.log(`\n${passed} checks passed.`);
