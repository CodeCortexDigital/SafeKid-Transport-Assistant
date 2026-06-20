import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/device/location_service.dart';
import '../services/firebase/firestore_service.dart';
import '../models/trip_model.dart';

class TripRepository {
  final LocationService _locationService;
  final FirestoreService _firestoreService;
  StreamSubscription<Position>? _locationSubscription;

  TripRepository(this._locationService, this._firestoreService);

  Future<TripModel> getTripDetails(String tripId) async {
    return await _firestoreService.getTrip(tripId);
  }

  Future<void> updateStatus(String tripId, TripStatus status) async {
    await _firestoreService.updateTripStatus(tripId, status);
  }

  Stream<TripModel> watchTrip(String tripId) {
    return _firestoreService.streamTrip(tripId);
  }

  /// Start sharing driver coordinates to Firestore for the active trip route
  Future<void> startSharingLocation(String tripId) async {
    await _locationService.checkPermissions();
    await stopSharingLocation();

    _locationSubscription = _locationService.getPositionStream().listen(
      (Position position) async {
        await _firestoreService.updateTripLocation(
          tripId, 
          position.latitude, 
          position.longitude
        );
      },
      onError: (_) {}
    );
  }

  Future<void> stopSharingLocation() async {
    if (_locationSubscription != null) {
      await _locationSubscription!.cancel();
      _locationSubscription = null;
    }
  }
}
