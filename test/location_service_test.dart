import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hrms/core/config/app_config.dart';
import 'package:hrms/features/attendance/services/location_service.dart';

void main() {
  group('LocationService', () {
    test('office coordinates produce a zero-distance fix', () async {
      expect(AppConfig.officeLatitude, 10.027786);
      expect(AppConfig.officeLongitude, 76.336622);

      final result = await _serviceFor(
        _position(AppConfig.officeLatitude, AppConfig.officeLongitude),
      ).verifyOfficeLocation();

      expect(result.distanceInMetres, closeTo(0, 0.01));
      expect(result.canRecordAttendance, isTrue);
    });

    test('accepts a deterministic fix inside 200 metres', () async {
      final result = await _serviceFor(
        _position(AppConfig.officeLatitude, AppConfig.officeLongitude + 0.0008),
      ).verifyOfficeLocation();

      expect(result.distanceInMetres, lessThan(200));
      expect(result.canRecordAttendance, isTrue);
    });

    test('rejects a deterministic fix outside 200 metres', () async {
      final result = await _serviceFor(
        _position(AppConfig.officeLatitude, AppConfig.officeLongitude + 0.003),
      ).verifyOfficeLocation();

      expect(result.distanceInMetres, greaterThan(200));
      expect(result.isWithinOfficeRange, isFalse);
    });

    test('keeps latitude and longitude in their original order', () async {
      const latitude = 12.916;
      const longitude = 77.629;
      final result = await _serviceFor(_position(latitude, longitude))
          .verifyOfficeLocation();

      expect(result.latitude, latitude);
      expect(result.longitude, longitude);
      expect(
        result.distanceInMetres,
        closeTo(
          Geolocator.distanceBetween(
            AppConfig.officeLatitude,
            AppConfig.officeLongitude,
            latitude,
            longitude,
          ),
          0.01,
        ),
      );
    });

    test('rejects invalid GPS coordinates', () async {
      for (final position in [
        _position(91, AppConfig.officeLongitude),
        _position(AppConfig.officeLatitude, 181),
      ]) {
        await expectLater(
          _serviceFor(position).verifyOfficeLocation(),
          throwsA(isA<LocationException>()),
        );
      }
    });

    test('reports missing location permission', () async {
      final platform = _FakeLocationPlatform(
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );

      await expectLater(
        LocationService(platform: platform).verifyOfficeLocation(),
        throwsA(
          isA<LocationException>().having(
            (error) => error.message,
            'message',
            contains('permission denied'),
          ),
        ),
      );
      expect(platform.positionRequested, isFalse);
    });

    test('reports permanently denied location permission', () async {
      final platform = _FakeLocationPlatform(
        permission: LocationPermission.deniedForever,
      );

      await expectLater(
        LocationService(platform: platform).verifyOfficeLocation(),
        throwsA(
          isA<LocationException>().having(
            (error) => error.message,
            'message',
            contains('permanently denied'),
          ),
        ),
      );
      expect(platform.positionRequested, isFalse);
    });

    test('reports disabled location services', () async {
      final platform = _FakeLocationPlatform(servicesEnabled: false);

      await expectLater(
        LocationService(platform: platform).verifyOfficeLocation(),
        throwsA(
          isA<LocationException>().having(
            (error) => error.message,
            'message',
            contains('services are disabled'),
          ),
        ),
      );
      expect(platform.positionRequested, isFalse);
    });

    test('reports a GPS timeout', () async {
      final platform = _FakeLocationPlatform(
        positionError: TimeoutException('test timeout'),
      );

      await expectLater(
        LocationService(platform: platform).verifyOfficeLocation(),
        throwsA(
          isA<LocationException>().having(
            (error) => error.message,
            'message',
            contains('Timed out'),
          ),
        ),
      );
    });

    test('does not accept an inaccurate fix even at the office', () async {
      final result = await _serviceFor(
        _position(
          AppConfig.officeLatitude,
          AppConfig.officeLongitude,
          accuracy: AppConfig.maximumLocationAccuracyMetres + 1,
        ),
      ).verifyOfficeLocation();

      expect(result.isWithinOfficeRange, isTrue);
      expect(result.isAccurate, isFalse);
      expect(result.canRecordAttendance, isFalse);
    });
  });
}

LocationService _serviceFor(Position position) =>
    LocationService(platform: _FakeLocationPlatform(position: position));

Position _position(double latitude, double longitude, {double accuracy = 5}) =>
    Position(
      longitude: longitude,
      latitude: latitude,
      timestamp: DateTime.utc(2026),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );

class _FakeLocationPlatform implements LocationPlatform {
  _FakeLocationPlatform({
    this.position,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    this.positionError,
    this.servicesEnabled = true,
  });

  final Position? position;
  final LocationPermission permission;
  final LocationPermission requestedPermission;
  final Object? positionError;
  final bool servicesEnabled;
  bool positionRequested = false;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings settings,
  }) async {
    positionRequested = true;
    if (positionError != null) throw positionError!;
    return position!;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => servicesEnabled;

  @override
  Future<LocationPermission> requestPermission() async => requestedPermission;
}
