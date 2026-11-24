import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';

class LocationVerificationResult {
  final double latitude;
  final double longitude;
  final double distanceInMetres;
  final double accuracyInMetres;

  const LocationVerificationResult({
    required this.latitude,
    required this.longitude,
    required this.distanceInMetres,
    required this.accuracyInMetres,
  });

  bool get isWithinOfficeRange =>
      distanceInMetres <= AppConfig.allowedOfficeRadiusMetres;

  bool get isAccurate =>
      accuracyInMetres <= AppConfig.maximumLocationAccuracyMetres;

  bool get canRecordAttendance => isWithinOfficeRange && isAccurate;
}

abstract interface class LocationPlatform {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<Position> getCurrentPosition({required LocationSettings settings});
}

class GeolocatorLocationPlatform implements LocationPlatform {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition({required LocationSettings settings}) =>
      Geolocator.getCurrentPosition(locationSettings: settings);
}

class LocationService {
  LocationService({LocationPlatform? platform})
    : _platform = platform ?? GeolocatorLocationPlatform();

  final LocationPlatform _platform;

  Future<LocationVerificationResult> verifyOfficeLocation() async {
    final serviceEnabled = await _platform.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationException(
        'Location services are disabled. Please enable GPS.',
      );
    }

    var permission = await _platform.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location permission denied. Allow location access to continue.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Enable it in Settings.',
      );
    }

    if (permission == LocationPermission.unableToDetermine) {
      throw const LocationException(
        'Unable to determine location permission. Please try again.',
      );
    }

    try {
      final position = await _platform.getCurrentPosition(
        settings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!position.latitude.isFinite ||
          position.latitude < -90 ||
          position.latitude > 90 ||
          !position.longitude.isFinite ||
          position.longitude < -180 ||
          position.longitude > 180) {
        throw const LocationException(
          'GPS returned invalid coordinates. Attendance was not recorded.',
        );
      }

      if (!position.accuracy.isFinite || position.accuracy < 0) {
        throw const LocationException(
          'GPS returned an invalid accuracy value. Attendance was not recorded.',
        );
      }

      final distance = Geolocator.distanceBetween(
        AppConfig.officeLatitude,
        AppConfig.officeLongitude,
        position.latitude,
        position.longitude,
      );

      return LocationVerificationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        distanceInMetres: distance,
        accuracyInMetres: position.accuracy,
      );
    } on TimeoutException {
      throw const LocationException(
        'Timed out while waiting for a GPS location. Please try again.',
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        'Location services became unavailable. Please enable GPS and try again.',
      );
    } catch (error) {
      if (error is LocationException) rethrow;

      throw LocationException(
        'Unable to retrieve your location. Please try again. ($error)',
      );
    }
  }
}

class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => message;
}
