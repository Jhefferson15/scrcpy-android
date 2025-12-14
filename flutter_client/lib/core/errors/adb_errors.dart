
abstract class AdbError implements Exception {
  final String message;
  AdbError(this.message);
  @override
  String toString() => "AdbError: $message";
}

class PairingFailedException extends AdbError {
  PairingFailedException(super.message);
}

class AuthError extends AdbError {
  AuthError(super.message);
}

class ConnectionFailedException extends AdbError {
  ConnectionFailedException(super.message);
}
