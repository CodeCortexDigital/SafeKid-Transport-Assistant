import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/location_repository.dart';
import '../models/ride_model.dart';

class LocationProvider extends ChangeNotifier {
  final LocationRepository _locationRepository;
  
  StreamSubscription<RideModel>? _rideSubscription;
  RideModel? _currentRide;
  bool _isSharingLocation = false;
  String? _errorMessage;

  RideModel? get currentRide => _currentRide;
  bool get isSharingLocation => _isSharingLocation;
  String? get errorMessage => _errorMessage;

  LocationProvider(this._locationRepository);

  /// Listens to live Firestore/Mock updates for an active trip/ride
  void startTrackingRide(String rideId) {
    _rideSubscription?.cancel();
    _errorMessage = null;

    _rideSubscription = _locationRepository.watchRide(rideId).listen(
      (ride) {
        _currentRide = ride;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = err.toString();
        notifyListeners();
      }
    );
  }

  /// Stops tracking active ride status updates
  void stopTrackingRide() {
    _rideSubscription?.cancel();
    _rideSubscription = null;
    _currentRide = null;
    notifyListeners();
  }

  /// Enables driver's own location sharing via GPS (updates Firestore)
  Future<void> startSharing(String rideId) async {
    _isSharingLocation = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _locationRepository.startSharingLocation(rideId);
    } catch (e) {
      _errorMessage = e.toString();
      _isSharingLocation = false;
    }
    notifyListeners();
  }

  /// Disables location sharing
  Future<void> stopSharing() async {
    await _locationRepository.stopSharingLocation();
    _isSharingLocation = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _locationRepository.stopSharingLocation();
    super.dispose();
  }
}
