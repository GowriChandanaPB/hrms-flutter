const assert = require("node:assert/strict");
const { after, before, beforeEach, test } = require("node:test");
const {
  app,
  calculateDistance,
  OFFICE_LOCATION,
  companyToday,
  getAvailableLeaveBalance,
  leaveRequests,
  attendanceEvents,
} = require("./server");

let server;
let baseUrl;

before(async () => {
  server = app.listen(0, "127.0.0.1");
  await new Promise((resolve) => server.once("listening", resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

beforeEach(() => {
  attendanceEvents.length = 0;
  leaveRequests.length = 0;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
});

test("employee endpoint returns the configured PG office", async () => {
  const response = await fetch(`${baseUrl}/employee/me`);
  const data = await response.json();

  assert.equal(response.status, 200);
  assert.equal(data.office.latitude, 12.915577);
  assert.equal(data.office.longitude, 77.628337);
  assert.equal(data.office.radiusInMetres, 200);
  assert.equal(data.office.timezone, "Asia/Kolkata");
  assert.deepEqual(OFFICE_LOCATION, data.office);
});

test("Haversine distance is zero at the office and symmetric", () => {
  const { latitude, longitude } = OFFICE_LOCATION;
  assert.equal(calculateDistance(latitude, longitude, latitude, longitude), 0);
  assert.equal(
    calculateDistance(latitude, longitude, latitude, longitude + 0.003),
    calculateDistance(latitude, longitude + 0.003, latitude, longitude),
  );
});

test("accepts office events and preserves idempotent retries", async () => {
  const event = makeEvent("inside-radius", OFFICE_LOCATION.latitude,
    OFFICE_LOCATION.longitude + 0.0008);
  const first = await postEvent(event);
  const retry = await postEvent(event);

  assert.equal(first.status, 201);
  assert.equal(retry.status, 200);
  assert.equal((await retry.json()).id, event.id);
});

test("server enforces employee identity, daily order, uniqueness, and immediate checkout", async () => {
  const checkoutFirst = await postEvent(
    makeEvent(
      "checkout-first",
      OFFICE_LOCATION.latitude,
      OFFICE_LOCATION.longitude,
      "check_out",
      "2099-12-11T09:00:00.000Z",
    ),
  );
  assert.equal(checkoutFirst.status, 409);
  assert.equal((await checkoutFirst.json()).code, "CHECK_IN_REQUIRED");

  const invalidEmployeeEvent = makeEvent(
    "invalid-employee-event",
    OFFICE_LOCATION.latitude,
    OFFICE_LOCATION.longitude,
  );
  invalidEmployeeEvent.employeeId = "OTHER";
  const invalidEmployee = await postEvent(invalidEmployeeEvent);
  assert.equal(invalidEmployee.status, 400);
  assert.equal((await invalidEmployee.json()).code, "INVALID_EMPLOYEE");

  const checkIn = makeEvent(
    "daily-check-in",
    OFFICE_LOCATION.latitude,
    OFFICE_LOCATION.longitude,
    "check_in",
    "2099-12-10T09:00:00.000Z",
  );
  const acceptedCheckIn = await postEvent(checkIn);
  assert.equal(acceptedCheckIn.status, 201);

  const duplicateCheckIn = await postEvent(
    makeEvent(
      "second-check-in",
      OFFICE_LOCATION.latitude,
      OFFICE_LOCATION.longitude,
      "check_in",
      "2099-12-10T09:00:01.000Z",
    ),
  );
  assert.equal(duplicateCheckIn.status, 409);
  assert.equal((await duplicateCheckIn.json()).code, "DUPLICATE_CHECK_IN");

  const checkOut = makeEvent(
    "immediate-check-out",
    OFFICE_LOCATION.latitude,
    OFFICE_LOCATION.longitude,
    "check_out",
    "2099-12-10T09:00:01.000Z",
  );
  const acceptedCheckOut = await postEvent(checkOut);
  assert.equal(acceptedCheckOut.status, 201);

  const duplicateCheckOut = await postEvent(
    makeEvent(
      "second-check-out",
      OFFICE_LOCATION.latitude,
      OFFICE_LOCATION.longitude,
      "check_out",
      "2099-12-10T09:00:02.000Z",
    ),
  );
  assert.equal(duplicateCheckOut.status, 409);
  assert.equal((await duplicateCheckOut.json()).code, "DUPLICATE_CHECK_OUT");

  const retry = await postEvent(checkOut);
  assert.equal(retry.status, 200);
  assert.equal((await retry.json()).id, checkOut.id);
});

test("rejects events outside 200 metres with HTTP 422", async () => {
  const event = makeEvent("outside-radius", OFFICE_LOCATION.latitude,
    OFFICE_LOCATION.longitude + 0.003);
  const response = await postEvent(event);

  assert.equal(response.status, 422);
  assert.equal((await response.json()).code, "OUTSIDE_OFFICE_RADIUS");
});

test("rejects non-numeric and invalid coordinate values", async () => {
  for (const [id, latitude, longitude] of [
    ["string-coordinate", "12.915577", 77.628337],
    ["invalid-latitude", 91, 77.628337],
    ["invalid-longitude", 12.915577, 181],
  ]) {
    const response = await postEvent(makeEvent(id, latitude, longitude));
    assert.equal(response.status, 400);
    assert.equal((await response.json()).code, "INVALID_COORDINATES");
  }
});

test("keeps duplicate and leave rejection scenarios", async () => {
  const duplicate = await postEvent(
    makeEvent("scenario-duplicate", OFFICE_LOCATION.latitude,
      OFFICE_LOCATION.longitude),
    { "x-mock-scenario": "duplicate" },
  );
  const leaveRejection = await fetch(`${baseUrl}/leave/requests`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-mock-scenario": "leave_rejection",
    },
    body: JSON.stringify({}),
  });

  assert.equal(duplicate.status, 409);
  assert.equal(leaveRejection.status, 422);
});

test("validates employee, type, dates, and reason on leave submission", async () => {
  const valid = makeLeave("invalid-base", "2098-01-05", "2098-01-05");
  const cases = [
    ["employee", { ...valid, employeeId: "OTHER" }, "INVALID_EMPLOYEE"],
    ["type", { ...valid, type: "annual" }, "INVALID_LEAVE_TYPE"],
    ["date", { ...valid, startDate: "2098-02-30" }, "INVALID_LEAVE_DATES"],
    ["past", { ...valid, startDate: yesterday(), endDate: yesterday() }, "PAST_START_DATE"],
    ["range", { ...valid, startDate: "2098-01-06", endDate: "2098-01-05" }, "INVALID_DATE_RANGE"],
    ["reason", { ...valid, reason: "  a b c d  " }, "INVALID_REASON"],
  ];

  for (const [suffix, body, expectedCode] of cases) {
    const response = await postLeave({ ...body, id: `invalid-${suffix}` });
    const expectedStatus = suffix === "employee" || suffix === "type" ? 400 : 422;
    assert.equal(response.status, expectedStatus);
    assert.equal((await response.json()).code, expectedCode);
  }
});

test("counts calendar days inclusively and deducts active leave balance", async () => {
  const before = await getLeaveBalance();
  const request = makeLeave("weekend-leave", "2098-01-10", "2098-01-11");
  const accepted = await postLeave(request);

  assert.equal(accepted.status, 201);
  assert.equal((await getLeaveBalance()).casualLeave, before.casualLeave - 2);

  const overlap = await postLeave(
    makeLeave("pending-overlap", "2098-01-11", "2098-01-12"),
  );
  assert.equal(overlap.status, 409);
  assert.equal((await overlap.json()).code, "LEAVE_OVERLAP");
});

test("enforces balance and preserves idempotent leave retries", async () => {
  const original = getAvailableLeaveBalance().sickLeave;
  const tooLong = makeLeave(
    "over-balance",
    "2098-03-01",
    new Date(Date.UTC(2098, 2, original + 1)).toISOString().slice(0, 10),
    "sick",
  );
  const rejected = await postLeave(tooLong);
  assert.equal(rejected.status, 422);
  assert.equal((await rejected.json()).code, "INSUFFICIENT_LEAVE_BALANCE");

  const valid = makeLeave("leave-idempotent", "2098-04-01", "2098-04-01");
  const first = await postLeave(valid);
  const retry = await postLeave(valid);
  assert.equal(first.status, 201);
  assert.equal(retry.status, 200);
});

test("pending and approved requests block overlaps, rejected requests do not", async () => {
  const beforeApproved = await getLeaveBalance();
  leaveRequests.push({
    ...makeLeave("approved-seed", "2098-05-01", "2098-05-02"),
    status: "approved",
  });
  leaveRequests.push({
    ...makeLeave("rejected-seed", "2098-06-01", "2098-06-02"),
    status: "rejected",
  });
  assert.equal(
    (await getLeaveBalance()).casualLeave,
    beforeApproved.casualLeave - 2,
  );

  const approvedOverlap = await postLeave(
    makeLeave("approved-overlap", "2098-05-02", "2098-05-03"),
  );
  const rejectedOverlap = await postLeave(
    makeLeave("rejected-overlap", "2098-06-01", "2098-06-02"),
  );

  assert.equal(approvedOverlap.status, 409);
  assert.equal((await approvedOverlap.json()).code, "LEAVE_OVERLAP");
  assert.equal(rejectedOverlap.status, 201);
});

test("rejected requests do not reduce available balance and scenario remains", async () => {
  const before = await getLeaveBalance();
  leaveRequests.push({
    ...makeLeave("rejected-balance-seed", "2098-07-01", "2098-07-03"),
    status: "rejected",
  });
  assert.deepEqual(await getLeaveBalance(), before);

  const scenario = await postLeave(
    makeLeave("leave-duplicate-scenario", "2098-08-01", "2098-08-01"),
    { "x-mock-scenario": "duplicate" },
  );
  assert.equal(scenario.status, 409);
});

test("accepts exactly 10 non-whitespace reason characters", async () => {
  const request = makeLeave("exact-reason", "2098-09-01", "2098-09-01", "sick");
  request.reason = " 12345 67890 ";
  const response = await postLeave(request);
  assert.equal(response.status, 201);
});

function makeEvent(
  id,
  latitude,
  longitude,
  type = "check_in",
  timestamp = new Date().toISOString(),
) {
  return {
    id,
    employeeId: "REBS-1024",
    type,
    timestamp,
    latitude,
    longitude,
  };
}

function postEvent(event, extraHeaders = {}) {
  return fetch(`${baseUrl}/attendance/events`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "Idempotency-Key": event.id,
      ...extraHeaders,
    },
    body: JSON.stringify(event),
  });
}

function makeLeave(id, startDate, endDate, type = "casual") {
  return {
    id,
    employeeId: "REBS-1024",
    type,
    startDate,
    endDate,
    reason: "Family appointment",
  };
}

function postLeave(request, extraHeaders = {}) {
  return fetch(`${baseUrl}/leave/requests`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "Idempotency-Key": request.id,
      ...extraHeaders,
    },
    body: JSON.stringify(request),
  });
}

async function getLeaveBalance() {
  const response = await fetch(`${baseUrl}/leave/balance`);
  return response.json();
}

function yesterday() {
  const [year, month, day] = companyToday().split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day - 1)).toISOString().slice(0, 10);
}