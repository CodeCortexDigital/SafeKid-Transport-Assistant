import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/device/location_service.dart';
import '../services/firebase/firestore_service.dart';
import '../models/ride_model.dart';

class LocationRepository {
  final LocationService _locationService;
  final FirestoreService _firestoreService;
  StreamSubscription<Position>? _locationSubscription;

  LocationRepository(this._locationService, this._firestoreService);

  Future<Position> getUserCurrentLocation() async {
    return await _locationService.getCurrentLocation();
  }

  Stream<RideModel> watchRide(String rideId) {
    return _firestoreService.streamRide(rideId);
  }

  /// Start sharing driver's coordinates to Firestore for the active ride
  Future<void> startSharingLocation(String rideId) async {
    await _locationService.checkPermissions();
    
    // Cancel any existing subscription
    await stopSharingLocation();

    _locationSubscription = _locationService.getPositionStream().listen(
      (Position position) async {
        await _firestoreService.updateRideLocation(
          rideId, 
          position.latitude, 
          position.longitude
        );
      },
      onError: (dynamic err) {
        // Handle error internally or expose to stream
      }
    );
  }

  Future<void> stopSharingLocation() async {
    if (_locationSubscription != null) {
      await _locationSubscription!.cancel();
      _locationSubscription = null;
    }
  }
}
