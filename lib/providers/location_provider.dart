import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/trip_repository.dart';
import '../models/trip_model.dart';

class LocationProvider extends ChangeNotifier {
  final TripRepository _tripRepository;
  
  StreamSubscription<TripModel>? _tripSubscription;
  TripModel? _currentTrip;
  bool _isSharingLocation = false;
  String? _errorMessage;

  TripModel? get currentTrip => _currentTrip;
  bool get isSharingLocation => _isSharingLocation;
  String? get errorMessage => _errorMessage;

  LocationProvider(this._tripRepository);

  /// Listens to live Firestore/Mock updates for an active trip route
  void startTrackingTrip(String tripId) {
    _tripSubscription?.cancel();
    _errorMessage = null;

    _tripSubscription = _tripRepository.watchTrip(tripId).listen(
      (trip) {
        _currentTrip = trip;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = err.toString();
        notifyListeners();
      }
    );
  }

  /// Stops tracking active trip status updates
  void stopTrackingTrip() {
    _tripSubscription?.cancel();
    _tripSubscription = null;
    _currentTrip = null;
    notifyListeners();
  }

  /// Enables driver's own location sharing via GPS (updates Firestore)
  Future<void> startSharing(String tripId) async {
    _isSharingLocation = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _tripRepository.startSharingLocation(tripId);
    } catch (e) {
      _errorMessage = e.toString();
      _isSharingLocation = false;
    }
    notifyListeners();
  }

  /// Disables location sharing
  Future<void> stopSharing() async {
    await _tripRepository.stopSharingLocation();
    _isSharingLocation = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    _tripRepository.stopSharingLocation();
    super.dispose();
  }
}
