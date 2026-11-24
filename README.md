# REBS HRMS – Offline-Capable Employee Workspace

A Flutter employee workspace for viewing attendance, recording check-in/check-out events, managing leave requests, and synchronizing attendance when connectivity is restored.

## Features

- **Employee dashboard:** Employee profile, daily attendance status, check-in/check-out times, working duration, leave balance, and recent attendance.
- **Attendance:** GPS-based check-in/check-out with a configurable 200-metre office geofence, permission handling, and duplicate-action prevention.
- **Offline support:** Cached employee and attendance data, locally persisted attendance events, Pending/Synced/Rejected states, manual synchronization, and automatic sync attempts when connectivity returns.
- **Reliable synchronization:** Ordered event processing and stable event IDs sent as idempotency keys to prevent duplicate server records during retries.
- **Leave management:** Casual and Sick leave requests with date, reason, balance, and overlapping-request validation.
- **Themes:** Light and dark appearance.
- **Mock API:** Local HTTP API for employee, attendance, and leave operations.

## Tech Stack

- Flutter and Dart
- Provider for state management
- Dio for HTTP requests
- SQLite (`sqflite`) for local persistence
- `connectivity_plus` for connectivity monitoring
- `geolocator` for location and geofence checks
- Node.js and Express for the mock API


## Setup

### Requirements

- Flutter SDK compatible with the version specified in `pubspec.yaml`
- Dart SDK
- Node.js and npm

### 1. Get the Flutter dependencies

```bash
flutter pub get
```

### 2. Start the mock API

Open a terminal:

```bash
cd mock_api
npm install
node server.js
npm run
```

Keep the API process running while testing the application.

Check the API base URL in the application's configuration and ensure it points to the machine hosting the mock API. For an iOS Simulator, the host machine can generally be reached through `localhost`; for a physical device, use the host machine's reachable LAN address.

### 3. Run the Flutter application

From the project root:

```bash
flutter run
```

## Configuration

- **Employee:** The mock API uses a preconfigured sample employee.
- **Office location:** Office coordinates and the allowed radius are configured in the application configuration. Keep the client and mock API office settings consistent.
- **Company timezone:** The attendance and leave rules use the configured company timezone. The current implementation is configured for `Asia/Kolkata`.
- **Mock data:** The mock API uses fixed sample employee and leave-balance data.

Do not publish private office coordinates or personal configuration values in the repository documentation.

## Location Testing

On the iOS Simulator:

1. Run the application.
2. Open **Features / Location** or the Simulator location controls, depending on the Xcode version.
3. Choose a simulated location or enter a custom coordinate.
4. Use a location within the configured 200-metre radius to test a valid attendance action.
5. Choose a location outside the radius to test geofence rejection.
6. Test location permission denial and unavailable location behavior where possible.

The Simulator location must be set close to the configured office location for a successful attendance action.

## Running Tests

Run the Flutter tests:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```

Run mock API tests:

```bash
cd mock_api
npm test
```

Record the results from the final run before submission. Do not treat earlier test results as verification of a later code snapshot.


