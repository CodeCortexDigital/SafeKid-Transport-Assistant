import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/device/location_service.dart';
import '../services/firebase/firestore_service.dart';
import '../models/trip_model.dart';

class TripRepository {
  final LocationService _locationService;
  final FirestoreService _firestoreService;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _locationTimer;

  TripRepository(this._locationService, this._firestoreService);

  Future<TripModel> getTripDetails(String tripId) async {
    return await _firestoreService.getTrip(tripId);
  }

  Future<void> updateStatus(String tripId, TripStatus status) async {
    await _firestoreService.updateTripStatus(tripId, status);
  }

  Future<void> updateRouteName(String tripId, String routeName) async {
    await _firestoreService.updateTripRouteName(tripId, routeName);
  }

  Stream<TripModel> watchTrip(String tripId) {
    return _firestoreService.streamTrip(tripId);
  }

  /// Start sharing driver coordinates to Firestore for the active trip route
  Future<void> startSharingLocation(String tripId) async {
    await _locationService.checkPermissions();
    await stopSharingLocation();

    Position? lastPosition;

    // Send immediate initial update
    try {
      lastPosition = await _locationService.getCurrentLocation();
      await _firestoreService.updateTripLocation(
        tripId, 
        lastPosition.latitude, 
        lastPosition.longitude
      );
    } catch (_) {}

    // Listen to device GPS coordinate streams
    _locationSubscription = _locationService.getPositionStream().listen(
      (Position position) {
        lastPosition = position;
      },
      onError: (_) {}
    );

    // Periodically post location updates to Firestore every 10 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (lastPosition == null) {
        try {
          lastPosition = await _locationService.getCurrentLocation();
        } catch (_) {}
      }

      if (lastPosition != null) {
        await _firestoreService.updateTripLocation(
          tripId, 
          lastPosition!.latitude, 
          lastPosition!.longitude
        );
      }
    });
  }

  Future<void> stopSharingLocation() async {
    if (_locationSubscription != null) {
      await _locationSubscription!.cancel();
      _locationSubscription = null;
    }
    if (_locationTimer != null) {
      _locationTimer!.cancel();
      _locationTimer = null;
    }
  }
}
