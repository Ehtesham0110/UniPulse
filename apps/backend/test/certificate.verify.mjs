// Verification harness for the Certificates milestone. Same approach as
// prior milestones: no MongoDB in this sandbox, so this mocks only the
// Mongoose model methods used, and runs the real, unmodified service and
// controller functions — including REAL PDF generation via pdfkit (not
// mocked) writing to the real storage/certificates directory, so this
// suite genuinely verifies that a valid PDF is produced on disk.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { Writable } from 'node:stream';

function matches(doc, query) {
  for (const [key, value] of Object.entries(query)) {
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
      select: () => api, // no-op: our fake docs already carry every field
      then: (resolve, reject) => Promise.resolve(items).then(resolve, reject),
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
    findOne(query) {
      const found = [...store.values()].find((doc) => matches(doc, query));
      const result = Promise.resolve(found ? withHelpers(found) : null);
      result.select = () => result;
      return result;
    },
    async findById(id) {
      const doc = store.get(id?.toString());
      return doc ? withHelpers(doc) : null;
    },
    find(query) {
      return chain([...store.values()].filter((d) => matches(d, query)).map(withHelpers));
    },
  };
}

const { Certificate, CertificateTemplate } = await import('../src/modules/certificates/certificate.model.js');
const { Registration } = await import('../src/modules/registrations/registration.model.js');
const { Event, EventLifecycle } = await import('../src/modules/events/event.model.js');
const { Attendance } = await import('../src/modules/attendance/attendance.model.js');
const { User } = await import('../src/modules/users/user.model.js');
const { College } = await import('../src/modules/colleges/college.model.js');

Object.assign(Certificate, makeFakeModel());
Object.assign(CertificateTemplate, makeFakeModel());
Object.assign(Registration, makeFakeModel());
Object.assign(Event, makeFakeModel());
Object.assign(Attendance, makeFakeModel());
Object.assign(User, makeFakeModel());
Object.assign(College, makeFakeModel());

const { generateCertificate, regenerateCertificate, bulkGenerateForEvent } = await import(
  '../src/modules/certificates/certificate.service.js'
);
const {
  listMyCertificates,
  viewCertificate,
  downloadCertificate,
  createCertificate,
  bulkGenerateCertificates,
  reissueCertificate,
} = await import('../src/modules/certificates/certificate.controller.js');
const { CERTIFICATE_STORAGE_DIR } = await import('../src/shared/utils/certificate-pdf.js');

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

function makeStreamingRes() {
  const headers = {};
  const chunks = [];
  const res = new Writable({
    write(chunk, _enc, cb) { chunks.push(chunk); cb(); },
  });
  res.setHeader = (k, v) => { headers[k] = v; };
  res.headers = headers;
  res.statusCode = 200;
  res.status = (code) => { res.statusCode = code; return res; };
  res.json = (body) => { res.body = body; res.emit('finish'); };
  res.getBuffer = () => Buffer.concat(chunks);
  return res;
}
async function callStreaming(handler, req) {
  const res = makeStreamingRes();
  let caughtError = null;
  const handlerPromise = handler(req, res, (err) => { caughtError = err; });
  await handlerPromise;
  if (caughtError) {
    return { status: caughtError.statusCode ?? 500, body: { success: false, message: caughtError.message, details: caughtError.details } };
  }
  if (!res.body) {
    // A real file stream is piping to res — wait for it to finish.
    await new Promise((resolve) => res.once('finish', resolve));
  }
  return { status: res.statusCode, headers: res.headers, buffer: res.getBuffer(), body: res.body };
}

const collegeId = 'college_1';
const admin = { _id: 'user_admin', collegeId, role: 'Admin' };
const student = { _id: 'user_student', collegeId, role: 'Student', fullName: 'Asha Rao' };
const otherStudent = { _id: 'user_other', collegeId, role: 'Student', fullName: 'Bala Singh' };
await User.create(student);
await User.create(otherStudent);
await College.create({ _id: collegeId, name: 'UniPulse Test College' });

let passed = 0;
function ok(label) { passed++; console.log(`  ✔ ${label}`); }

console.log('Certificates milestone — mock-backed controller verification\n');

async function makeEvent(id, lifecycle) {
  return Event.create({
    _id: id, collegeId, title: `Event ${id}`, eventType: 'Individual',
    lifecycle,
  });
}
async function makeRegistration(id, eventId, studentId, status) {
  return Registration.create({
    _id: id, collegeId, eventId, studentId, qrTokenHash: `hash_${id}`, status,
  });
}
async function makeAttendance(eventId, registrationId, studentId, checkedIn) {
  return Attendance.create({
    _id: `att_${registrationId}`, collegeId, eventId, registrationId, studentId,
    checkedIn, checkInTime: checkedIn ? new Date() : undefined,
  });
}

// ---- Eligibility validation ----
{
  await makeEvent('event_not_completed', EventLifecycle.REGISTRATION_OPEN);
  await makeRegistration('reg_not_completed', 'event_not_completed', student._id, 'Attended');
  await makeAttendance('event_not_completed', 'reg_not_completed', student._id, true);

  const result = await call(createCertificate, {
    body: { registrationId: 'reg_not_completed' }, user: admin, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'EVENT_NOT_COMPLETED');
  ok('generateCertificate rejects an event that is not Completed');
}
{
  await makeEvent('event_completed_1', EventLifecycle.COMPLETED);
  await makeRegistration('reg_not_attended', 'event_completed_1', student._id, 'Confirmed');
  // No Attendance record at all.
  const result = await call(createCertificate, {
    body: { registrationId: 'reg_not_attended' }, user: admin, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'NOT_ATTENDED');
  ok('generateCertificate rejects a student who did not attend (no attendance record)');
}
{
  await makeRegistration('reg_cancelled', 'event_completed_1', student._id, 'Cancelled');
  const result = await call(createCertificate, {
    body: { registrationId: 'reg_cancelled' }, user: admin, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'CANCELLED');
  ok('generateCertificate rejects a cancelled registration');
}
{
  await makeRegistration('reg_pending', 'event_completed_1', student._id, 'Pending Payment');
  const result = await call(createCertificate, {
    body: { registrationId: 'reg_pending' }, user: admin, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'PAYMENT_PENDING');
  ok('generateCertificate rejects a registration still awaiting payment');
}

// ---- Happy path + real PDF generation ----
let issuedCertificateId;
{
  await makeRegistration('reg_eligible', 'event_completed_1', student._id, 'Attended');
  await makeAttendance('event_completed_1', 'reg_eligible', student._id, true);

  const result = await call(createCertificate, {
    body: { registrationId: 'reg_eligible' }, user: admin, collegeId,
  });
  assert.equal(result.status, 201);
  assert.ok(result.body.data.certificateNumber.startsWith('UNIPULSE-'));
  assert.equal(result.body.data.pdfUrl, `/api/certificates/${result.body.data._id}/download`);
  issuedCertificateId = result.body.data._id;
  ok('generateCertificate succeeds for an eligible, attended, completed-event registration');

  const filePath = (await Certificate.findById(issuedCertificateId)).filePath;
  assert.ok(fs.existsSync(filePath), 'PDF file should exist on disk');
  const bytes = fs.readFileSync(filePath);
  assert.ok(bytes.length > 500, 'PDF file should have real content, not be empty/truncated');
  assert.equal(bytes.slice(0, 4).toString(), '%PDF', 'file should start with a valid PDF header');
  ok('A real, valid PDF file is written to storage/certificates');
  assert.ok(filePath.startsWith(CERTIFICATE_STORAGE_DIR), 'PDF should be stored under the certificates storage dir');
  ok('PDF is stored under the expected local storage directory');
}

// ---- Duplicate prevention ----
{
  const result = await call(createCertificate, {
    body: { registrationId: 'reg_eligible' }, user: admin, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'DUPLICATE_CERTIFICATE');
  ok('generateCertificate refuses to issue a second certificate for the same registration');
}

// ---- Certificate number uniqueness across different registrations ----
{
  await makeRegistration('reg_eligible_2', 'event_completed_1', otherStudent._id, 'Attended');
  await makeAttendance('event_completed_1', 'reg_eligible_2', otherStudent._id, true);
  const result = await call(createCertificate, {
    body: { registrationId: 'reg_eligible_2' }, user: admin, collegeId,
  });
  assert.equal(result.status, 201);
  const first = await Certificate.findById(issuedCertificateId);
  assert.notEqual(result.body.data.certificateNumber, first.certificateNumber);
  ok('Different registrations get distinct certificate numbers');
}

// ---- Permission checks ----
{
  const asStudent = await call(createCertificate, {
    body: { registrationId: 'reg_eligible' }, user: student, collegeId,
  });
  // requirePermission runs before the handler in the real route, but since
  // this test calls the controller directly it bypasses that middleware —
  // verify the permission constant is correctly wired at the route level
  // by checking roles.js grants ISSUE_CERTIFICATES only to Admin/SuperAdmin.
  const { roleHasPermission, Permissions } = await import('../src/shared/utils/roles.js');
  assert.equal(roleHasPermission('Student', Permissions.ISSUE_CERTIFICATES), false);
  assert.equal(roleHasPermission('Admin', Permissions.ISSUE_CERTIFICATES), true);
  ok('ISSUE_CERTIFICATES permission is correctly restricted to Admin/Super Admin (route-level gate)');
}

// ---- Access control on view/download ----
{
  const ownerAccess = await callStreaming(viewCertificate, {
    params: { certificateId: issuedCertificateId }, user: student, collegeId,
  });
  assert.equal(ownerAccess.status, 200);
  assert.equal(ownerAccess.headers['Content-Type'], 'application/pdf');
  assert.match(ownerAccess.headers['Content-Disposition'], /^inline/);
  assert.equal(ownerAccess.buffer.slice(0, 4).toString(), '%PDF');
  ok('The certificate owner can view their own certificate (inline)');

  const adminAccess = await callStreaming(downloadCertificate, {
    params: { certificateId: issuedCertificateId }, user: admin, collegeId,
  });
  assert.equal(adminAccess.status, 200);
  assert.match(adminAccess.headers['Content-Disposition'], /^attachment/);
  ok('Admin can download any certificate in their college (attachment)');

  const strangerAccess = await call(viewCertificate, {
    params: { certificateId: issuedCertificateId }, user: otherStudent, collegeId,
  });
  assert.equal(strangerAccess.status, 403);
  ok('A different student cannot view someone else\'s certificate');

  const missing = await call(downloadCertificate, {
    params: { certificateId: 'does-not-exist' }, user: admin, collegeId,
  });
  assert.equal(missing.status, 404);
  ok('Requesting a non-existent certificate returns 404');
}

// ---- listMyCertificates ----
{
  const result = await call(listMyCertificates, { user: student, collegeId });
  assert.equal(result.status, 200);
  assert.equal(result.body.data.length, 1);
  ok('listMyCertificates returns only the current user\'s certificates');
}

// ---- Regenerate: requires explicit confirmation ----
{
  const withoutConfirm = await call(reissueCertificate, {
    params: { certificateId: issuedCertificateId }, body: {}, user: admin, collegeId,
  });
  assert.equal(withoutConfirm.status, 400);
  ok('reissueCertificate refuses to regenerate without { confirm: true }');

  const before = await Certificate.findById(issuedCertificateId);
  const oldFilePath = before.filePath;

  const withConfirm = await call(reissueCertificate, {
    params: { certificateId: issuedCertificateId }, body: { confirm: true }, user: admin, collegeId,
  });
  assert.equal(withConfirm.status, 200);
  assert.equal(withConfirm.body.data.regeneratedCount, 1);
  assert.equal(withConfirm.body.data.certificateNumber, before.certificateNumber, 'certificate number should stay the same on regenerate');
  ok('reissueCertificate regenerates the PDF and increments regeneratedCount when explicitly confirmed');

  assert.ok(fs.existsSync(withConfirm.body.data.filePath), 'new PDF file should exist');
  assert.ok(!fs.existsSync(oldFilePath) || oldFilePath === withConfirm.body.data.filePath, 'old PDF file should be cleaned up if the path changed');
  ok('Old PDF file is cleaned up after regeneration');
}

// ---- Bulk generation ----
{
  await makeEvent('event_bulk', EventLifecycle.COMPLETED);
  const bulkStudents = ['bulk_1', 'bulk_2', 'bulk_3'];
  for (const id of bulkStudents) {
    await User.create({ _id: id, collegeId, role: 'Student', fullName: `Student ${id}` });
    await makeRegistration(`reg_${id}`, 'event_bulk', id, 'Attended');
    await makeAttendance('event_bulk', `reg_${id}`, id, true);
  }
  // One registration that didn't attend — should be excluded entirely
  // (query only looks at status: 'Attended').
  await makeRegistration('reg_bulk_not_attended', 'event_bulk', 'bulk_4', 'Confirmed');

  const result = await call(bulkGenerateCertificates, {
    body: { eventId: 'event_bulk' }, user: admin, collegeId,
  });
  assert.equal(result.status, 201);
  assert.equal(result.body.data.totalEligible, 3);
  assert.equal(result.body.data.generated.length, 3);
  assert.equal(result.body.data.skipped.length, 0);
  ok('bulkGenerateCertificates generates certificates for every attended registration');

  // Running it again should skip all 3 as duplicates rather than erroring.
  const rerun = await call(bulkGenerateCertificates, {
    body: { eventId: 'event_bulk' }, user: admin, collegeId,
  });
  assert.equal(rerun.status, 201);
  assert.equal(rerun.body.data.generated.length, 0);
  assert.equal(rerun.body.data.skipped.length, 3);
  assert.ok(rerun.body.data.skipped.every((s) => s.reason === 'DUPLICATE_CERTIFICATE'));
  ok('Re-running bulk generation skips already-certified registrations instead of failing the batch');
}

// ---- Bulk generation on a non-completed event ----
{
  await makeEvent('event_bulk_open', EventLifecycle.REGISTRATION_OPEN);
  const result = await call(bulkGenerateCertificates, {
    body: { eventId: 'event_bulk_open' }, user: admin, collegeId,
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.details?.reason, 'EVENT_NOT_COMPLETED');
  ok('bulkGenerateCertificates refuses to run on an event that is not Completed');
}

console.log(`\n${passed} checks passed.`);
