import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../core/errors/failures.dart';

abstract class LocationService {
  Future<Position> getCurrentLocation();
  Stream<Position> getPositionStream();
  Future<bool> checkPermissions();
}

class DeviceLocationService implements LocationService {
  @override
  Future<bool> checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure('Location services are disabled on this device.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionFailure('Location permissions are denied.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw const PermissionFailure(
        'Location permissions are permanently denied, we cannot request permissions.'
      );
    }

    return true;
  }

  @override
  Future<Position> getCurrentLocation() async {
    try {
      await checkPermissions();
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw LocationFailure(e.toString());
    }
  }

  @override
  Stream<Position> getPositionStream() {
    // Configure settings for location updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update location every 10 meters
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .handleError((dynamic error) {
          throw LocationFailure(error.toString());
        });
  }
}

class MockLocationService implements LocationService {
  @override
  Future<bool> checkPermissions() async => true;

  @override
  Future<Position> getCurrentLocation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Position(
      latitude: 40.760000,
      longitude: -73.985000,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 10.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 1.0,
      headingAccuracy: 1.0,
    );
  }

  @override
  Stream<Position> getPositionStream() {
    double progress = 0.0;
    return Stream.periodic(const Duration(seconds: 4), (count) {
      progress = (count % 20) / 20.0;
      double lat = 40.760000 + (40.785091 - 40.760000) * progress;
      double lng = -73.985000 + (-73.968285 - -73.985000) * progress;
      
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        heading: 0.0,
        speed: 5.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
    });
  }
}
