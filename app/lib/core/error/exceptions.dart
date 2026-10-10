/// Exceptions thrown by the data layer. Repositories catch them and turn
/// them into [Failure]s, so nothing above the data layer sees these.
sealed class DataException implements Exception {
  const DataException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The hub answered with an error status and an Error body.
class ApiException extends DataException {
  const ApiException({required this.statusCode, required this.code, required String message}) : super(message);
  final int statusCode;
  final String code;
}

/// The hub could not be reached (DNS, refused, Tailscale down...).
class NetworkException extends DataException {
  const NetworkException(super.message);
}

/// The hub did not answer in time.
class RequestTimeoutException extends DataException {
  const RequestTimeoutException(super.message);
}

/// The hub answered with something that isn't valid protocol JSON.
class ProtocolException extends DataException {
  const ProtocolException(super.message);
}

/// Local storage (preferences, keystore) failed.
class StorageException extends DataException {
  const StorageException(super.message);
}
