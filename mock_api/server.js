const express = require("express");
const cors = require("cors");
const crypto = require("crypto");

const app = express();
app.use(cors());
app.use(express.json());

const PORT = 3001;
const EMPLOYEE_ID = "REBS-1024";

// PG configured as the attendance office.
const OFFICE_LOCATION = {
  latitude: 10.027786,
  longitude: 76.336622,
  radiusInMetres: 200,
  timezone: "Asia/Kolkata",
};

const employee = {
  id: EMPLOYEE_ID,
  name: "Gowri",
  department: "Mobile",
  designation: "Flutter Developer",
  email: "alex@rebs.example",
};

const office = { ...OFFICE_LOCATION };

let attendanceEvents = [
  {
    id: "demo-2026-11-24-check-in",
    employeeId: EMPLOYEE_ID,
    type: "check_in",
    timestamp: "2026-11-24T03:45:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
  {
    id: "demo-2026-11-24-check-out",
    employeeId: EMPLOYEE_ID,
    type: "check_out",
    timestamp: "2026-11-24T12:40:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
  {
    id: "demo-2026-11-23-check-in",
    employeeId: EMPLOYEE_ID,
    type: "check_in",
    timestamp: "2026-11-23T03:30:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
  {
    id: "demo-2026-11-23-check-out",
    employeeId: EMPLOYEE_ID,
    type: "check_out",
    timestamp: "2026-11-23T12:35:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
  {
    id: "demo-2026-11-21-check-in",
    employeeId: EMPLOYEE_ID,
    type: "check_in",
    timestamp: "2026-11-21T03:40:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
  {
    id: "demo-2026-11-21-check-out",
    employeeId: EMPLOYEE_ID,
    type: "check_out",
    timestamp: "2026-11-21T12:30:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
  {
    id: "demo-2026-11-20-check-in",
    employeeId: EMPLOYEE_ID,
    type: "check_in",
    timestamp: "2026-11-20T03:35:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
  {
    id: "demo-2026-11-20-check-out",
    employeeId: EMPLOYEE_ID,
    type: "check_out",
    timestamp: "2026-11-20T12:25:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
  {
    id: "demo-2026-11-19-check-in",
    employeeId: EMPLOYEE_ID,
    type: "check_in",
    timestamp: "2026-11-19T03:50:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
  {
    id: "demo-2026-11-19-check-out",
    employeeId: EMPLOYEE_ID,
    type: "check_out",
    timestamp: "2026-11-19T12:45:00.000Z",
    latitude: OFFICE_LOCATION.latitude,
    longitude: OFFICE_LOCATION.longitude,
    syncStatus: "synced",
  },
];
let leaveRequests = [];

const leaveBalanceAllocation = {
  casualLeave: 8,
  sickLeave: 8,
};

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function sendError(res, status, message, code, extra = {}) {
  return res.status(status).json({ message, code, ...extra });
}

// Calculate distance between two GPS coordinates using the Haversine formula.
function calculateDistance(lat1, lon1, lat2, lon2) {
  const earthRadius = 6371000;

  const toRadians = (degrees) => (degrees * Math.PI) / 180;

  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) ** 2;

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return earthRadius * c;
}

// Mock scenarios:
// x-mock-scenario: slow | server_error | duplicate | leave_rejection

app.use(async (req, res, next) => {
  const scenario = req.header("x-mock-scenario");

  if (scenario === "slow") {
    await delay(20000);
  }

  if (scenario === "server_error") {
    return sendError(
      res,
      500,
      "Simulated server failure.",
      "MOCK_SERVER_ERROR"
    );
  }

  next();
});

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

app.get("/employee/me", (req, res) => {
  res.json({
    ...employee,
    office,
  });
});

app.get("/attendance", (req, res) => {
  const month = req.query.month;

  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month || "")) {
    return sendError(
      res,
      400,
      "month must use YYYY-MM format.",
      "INVALID_MONTH"
    );
  }

  const events = attendanceEvents.filter(
    (event) => companyMonth(event.timestamp) === month
  );

  res.json(events);
});

app.post("/attendance/events", (req, res) => {
  const event = req.body;

  if (!event || typeof event !== "object" || Array.isArray(event)) {
    return sendError(res, 400, "Invalid attendance event.", "INVALID_EVENT");
  }

  if (event.employeeId !== EMPLOYEE_ID) {
    return sendError(
      res,
      400,
      "Unknown employee ID.",
      "INVALID_EMPLOYEE"
    );
  }

  const idempotencyKey = req.header("Idempotency-Key") || event.id;

  if (!idempotencyKey) {
    return sendError(
      res,
      400,
      "Event ID is required.",
      "MISSING_EVENT_ID"
    );
  }

  // Return an existing event when the same request is retried.
  const existingById = attendanceEvents.find(
    (item) => item.id === idempotencyKey
  );

  if (existingById) {
    return res.status(200).json(existingById);
  }

  if (!event.type || !event.timestamp) {
    return sendError(
      res,
      400,
      "Invalid attendance event.",
      "INVALID_EVENT"
    );
  }

  if (!["check_in", "check_out"].includes(event.type)) {
    return sendError(
      res,
      400,
      "Unsupported attendance event type.",
      "INVALID_TYPE"
    );
  }

  const eventTime = new Date(event.timestamp);
  if (typeof event.timestamp !== "string" ||
      !Number.isFinite(eventTime.getTime())) {
    return sendError(
      res,
      400,
      "A valid attendance timestamp is required.",
      "INVALID_TIMESTAMP"
    );
  }

  // Validate GPS coordinates.
  const { latitude, longitude } = event;

  if (
    typeof latitude !== "number" ||
    typeof longitude !== "number" ||
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    return sendError(
      res,
      400,
      "Valid attendance coordinates are required.",
      "INVALID_COORDINATES"
    );
  }

  // Server-side office radius validation.
  const distance = calculateDistance(
    OFFICE_LOCATION.latitude,
    OFFICE_LOCATION.longitude,
    latitude,
    longitude
  );

  if (distance > OFFICE_LOCATION.radiusInMetres) {
    return sendError(
      res,
      422,
      "You are outside the permitted office radius.",
      "OUTSIDE_OFFICE_RADIUS",
      {
        distanceInMetres: Math.round(distance),
        allowedRadius: OFFICE_LOCATION.radiusInMetres,
      }
    );
  }

  const eventDay = companyDateKey(eventTime);
  const sameDayEvents = attendanceEvents.filter(
    (item) => item.employeeId === EMPLOYEE_ID &&
      companyDateKey(new Date(item.timestamp)) === eventDay
  );

  if (event.type === "check_in") {
    if (sameDayEvents.some((item) => item.type === "check_in")) {
      return sendError(
        res,
        409,
        "A check-in has already been recorded for this working day.",
        "DUPLICATE_CHECK_IN"
      );
    }
    if (sameDayEvents.some((item) => item.type === "check_out")) {
      return sendError(
        res,
        409,
        "A check-in cannot be recorded after check-out.",
        "CHECK_IN_AFTER_CHECK_OUT"
      );
    }
  } else {
    if (sameDayEvents.some((item) => item.type === "check_out")) {
      return sendError(
        res,
        409,
        "A check-out has already been recorded for this working day.",
        "DUPLICATE_CHECK_OUT"
      );
    }
    const hasPriorCheckIn = sameDayEvents.some(
      (item) => item.type === "check_in" &&
        Number.isFinite(Date.parse(item.timestamp)) &&
        Date.parse(item.timestamp) <= eventTime.getTime()
    );
    if (!hasPriorCheckIn) {
      return sendError(
        res,
        409,
        "A valid check-in is required before check-out.",
        "CHECK_IN_REQUIRED"
      );
    }
  }

  const scenario = req.header("x-mock-scenario");

  if (scenario === "duplicate") {
    return sendError(
      res,
      409,
      "Attendance event already exists for this session.",
      "ATTENDANCE_CONFLICT"
    );
  }

  const savedEvent = {
    ...event,
    id: idempotencyKey,
    syncStatus: "synced",
  };

  attendanceEvents.push(savedEvent);

  res.status(201).json(savedEvent);
});

app.get("/leave/balance", (req, res) => {
  res.json(getAvailableLeaveBalance());
});

app.get("/leave/requests", (req, res) => {
  res.json(leaveRequests);
});

app.post("/leave/requests", (req, res) => {
  const request = req.body;
  const scenario = req.header("x-mock-scenario");

  if (scenario === "leave_rejection") {
    return sendError(
      res,
      422,
      "The selected dates are not eligible for leave.",
      "LEAVE_VALIDATION_FAILED"
    );
  }

  if (!request || typeof request !== "object" || Array.isArray(request)) {
    return sendError(
      res,
      400,
      "A leave request body is required.",
      "INVALID_LEAVE"
    );
  }

  const idempotencyKey = req.header("Idempotency-Key") || request.id;
  if (typeof idempotencyKey !== "string" || idempotencyKey.trim() === "") {
    return sendError(
      res,
      400,
      "A request ID is required for duplicate submission protection.",
      "MISSING_REQUEST_ID"
    );
  }

  const existingById = leaveRequests.find(
    (item) => item.id === idempotencyKey || item.id === request.id
  );
  if (existingById) return res.status(200).json(existingById);

  if (request.employeeId !== EMPLOYEE_ID) {
    return sendError(
      res,
      400,
      "Unknown employee ID.",
      "INVALID_EMPLOYEE"
    );
  }

  if (!["casual", "sick"].includes(request.type)) {
    return sendError(
      res,
      400,
      "Leave type must be casual or sick.",
      "INVALID_LEAVE_TYPE"
    );
  }

  const startDate = parseLeaveDate(request.startDate);
  const endDate = parseLeaveDate(request.endDate);

  if (
    startDate === null ||
    endDate === null
  ) {
    return sendError(
      res,
      422,
      "Start and end dates must be valid calendar dates in YYYY-MM-DD format.",
      "INVALID_LEAVE_DATES"
    );
  }

  const today = companyToday();
  if (startDate < today) {
    return sendError(
      res,
      422,
      `Leave start date cannot be before today (${today}) in ${OFFICE_LOCATION.timezone}.`,
      "PAST_START_DATE"
    );
  }

  if (endDate < startDate) {
    return sendError(
      res,
      422,
      "End date cannot be before the start date.",
      "INVALID_DATE_RANGE"
    );
  }

  if (typeof request.reason !== "string") {
    return sendError(
      res,
      400,
      "A leave reason is required.",
      "INVALID_REASON"
    );
  }

  const normalizedReason = request.reason.trim();
  const reasonLength = normalizedReason.replace(/\s/g, "").length;

  if (reasonLength < 10) {
    return sendError(
      res,
      422,
      "Reason must contain at least 10 non-whitespace characters.",
      "INVALID_REASON"
    );
  }

  const requestedDays = calendarDaysInclusive(startDate, endDate);
  const availableBalance = getAvailableLeaveBalance();
  const availableDays = request.type === "casual"
    ? availableBalance.casualLeave
    : availableBalance.sickLeave;

  if (requestedDays > availableDays) {
    return sendError(
      res,
      422,
      `Requested ${requestedDays} days exceeds the available ${availableDays} days of ${request.type} leave.`,
      "INSUFFICIENT_LEAVE_BALANCE",
      { requestedDays, availableDays }
    );
  }

  const duplicateSubmission = leaveRequests.find((item) =>
    item.employeeId === request.employeeId &&
    ["pending", "approved"].includes(item.status) &&
    item.type === request.type &&
    parseLeaveDate(item.startDate) === startDate &&
    parseLeaveDate(item.endDate) === endDate &&
    item.reason.trim() === normalizedReason
  );
  if (duplicateSubmission) {
    return sendError(
      res,
      409,
      "This leave request has already been submitted.",
      "DUPLICATE_LEAVE_REQUEST"
    );
  }

  const overlaps = leaveRequests.some((item) => {
    const active = ["pending", "approved"].includes(item.status);
    const itemStart = parseLeaveDate(item.startDate);
    const itemEnd = parseLeaveDate(item.endDate);

    return item.employeeId === request.employeeId &&
      active &&
      itemStart !== null &&
      itemEnd !== null &&
      itemStart <= endDate &&
      itemEnd >= startDate;
  });

  if (overlaps) {
    return sendError(
      res,
      409,
      "Leave dates overlap an existing pending or approved request.",
      "LEAVE_OVERLAP"
    );
  }

  if (scenario === "duplicate") {
    return sendError(
      res,
      409,
      "Leave request already exists for this session.",
      "DUPLICATE_LEAVE_REQUEST"
    );
  }

  const savedRequest = {
    ...request,
    id: idempotencyKey || crypto.randomUUID(),
    startDate,
    endDate,
    reason: normalizedReason,
    status: "pending",
  };

  leaveRequests.push(savedRequest);

  res.status(201).json(savedRequest);
});

function parseLeaveDate(value) {
  if (typeof value !== "string") return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})(?:$|T)/.exec(value);
  if (!match) return null;
  if (value.includes("T") && Number.isNaN(Date.parse(value))) return null;

  const [, yearText, monthText, dayText] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) return null;

  return `${yearText}-${monthText}-${dayText}`;
}

function companyDateKey(value) {
  const date = value instanceof Date ? value : new Date(value);
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: OFFICE_LOCATION.timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const part = (type) => parts.find((item) => item.type === type).value;
  return `${part("year")}-${part("month")}-${part("day")}`;
}

function companyMonth(timestamp) {
  return companyDateKey(timestamp).substring(0, 7);
}

function companyToday(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: OFFICE_LOCATION.timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const part = (type) => parts.find((item) => item.type === type).value;
  return `${part("year")}-${part("month")}-${part("day")}`;
}

function calendarDaysInclusive(start, end) {
  const [startYear, startMonth, startDay] = start.split("-").map(Number);
  const [endYear, endMonth, endDay] = end.split("-").map(Number);
  return (Date.UTC(endYear, endMonth - 1, endDay) -
    Date.UTC(startYear, startMonth - 1, startDay)) / 86400000 + 1;
}

function getAvailableLeaveBalance() {
  const balance = { ...leaveBalanceAllocation };
  for (const request of leaveRequests) {
    if (
      request.employeeId !== EMPLOYEE_ID ||
      !["pending", "approved"].includes(request.status)
    ) continue;

    const start = parseLeaveDate(request.startDate);
    const end = parseLeaveDate(request.endDate);
    if (start === null || end === null || end < start) continue;
    const days = calendarDaysInclusive(start, end);
    if (request.type === "casual") balance.casualLeave -= days;
    if (request.type === "sick") balance.sickLeave -= days;
  }
  return {
    casualLeave: Math.max(0, balance.casualLeave),
    sickLeave: Math.max(0, balance.sickLeave),
  };
}

if (require.main === module) {
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`REBS mock API running on http://localhost:${PORT}`);
    console.log(
      `Office location: ${OFFICE_LOCATION.latitude}, ${OFFICE_LOCATION.longitude}`
    );
    console.log(`Allowed radius: ${OFFICE_LOCATION.radiusInMetres} metres`);
  });
}

module.exports = {
  app,
  calculateDistance,
  OFFICE_LOCATION,
  companyToday,
  companyDateKey,
  companyMonth,
  calendarDaysInclusive,
  getAvailableLeaveBalance,
  attendanceEvents,
  leaveRequests,
};
