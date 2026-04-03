// Custom application exceptions

/// Base exception for all habit tracker errors.
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a database operation fails.
class DatabaseException extends AppException {
  const DatabaseException(super.message);
}

/// Thrown when a requested resource is not found.
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Thrown when input validation fails.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Thrown when a network/Firebase operation fails.
class NetworkException extends AppException {
  const NetworkException(super.message);
}
