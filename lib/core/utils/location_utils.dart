import 'package:geolocator/geolocator.dart';

class LocationUtils {
  /// Assumed average transit speed of the van in km/h (typical school route speed in residential areas is ~30 km/h)
  static const double averageSpeedKmH = 30.0;

  /// Calculates the geodesic distance between two points in meters
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculates the Estimated Time of Arrival (ETA) in minutes based on distance and average speed
  static int calculateEtaMinutes(double distanceInMeters) {
    if (distanceInMeters <= 50.0) {
      return 0; // Less than 50 meters is considered arrived / arriving now
    }
    
    // Speed in meters per second (30 km/h = 8.33 m/s)
    final double speedMps = (averageSpeedKmH * 1000) / 3600.0;
    final double seconds = distanceInMeters / speedMps;
    
    // Return rounded up ceiling value of minutes
    return (seconds / 60.0).ceil();
  }
}
