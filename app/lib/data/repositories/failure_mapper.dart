import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/result.dart';

/// Converts data-layer exceptions into domain failures.
Failure failureFrom(Object error) => switch (error) {
      ApiException(statusCode: 401) || ApiException(code: 'unauthorized') => UnauthorizedFailure(error.message),
      ApiException(code: 'not_found') => NotFoundFailure(error.message),
      ApiException(code: 'node_offline') => NodeOfflineFailure(error.message),
      ApiException(code: 'terminal_active') => TerminalActiveFailure(error.message),
      ApiException(code: 'invalid') => ValidationFailure(error.message),
      ApiException(:final code, :final message) => ServerFailure(message, code: code),
      NetworkException(:final message) => NetworkFailure(message),
      RequestTimeoutException(:final message) => TimeoutFailure(message),
      ProtocolException(:final message) => ServerFailure(message, code: 'protocol'),
      StorageException(:final message) => StorageFailure(message),
      _ => UnexpectedFailure(error.toString()),
    };

/// Runs [body] and wraps its value, or the failure it threw, in a [Result].
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on Exception catch (e) {
    return Err(failureFrom(e));
  } on Error catch (e) {
    return Err(UnexpectedFailure(e.toString()));
  }
}
