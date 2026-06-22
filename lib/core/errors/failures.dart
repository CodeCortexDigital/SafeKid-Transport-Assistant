abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No Internet Connection. Please check your network settings.']);
}

class LocationFailure extends Failure {
  const LocationFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
