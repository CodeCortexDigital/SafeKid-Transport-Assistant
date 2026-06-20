import '../services/firebase/firestore_service.dart';
import '../models/vehicle_model.dart';

class VehicleRepository {
  final FirestoreService _firestoreService;

  VehicleRepository(this._firestoreService);

  Future<VehicleModel> getVehicleDetails(String vehicleId) async {
    return await _firestoreService.getVehicle(vehicleId);
  }

  Future<void> updateLocation(String vehicleId, double latitude, double longitude) async {
    await _firestoreService.updateVehicleLocation(vehicleId, latitude, longitude);
  }

  Stream<VehicleModel> watchVehicle(String vehicleId) {
    return _firestoreService.streamVehicle(vehicleId);
  }
}
