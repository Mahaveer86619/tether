import 'error/failures.dart';

/// The outcome of a repository or use case call: a value or a [Failure].
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onSuccess) => switch (this) {
        Ok<T>(:final value) => onSuccess(value),
        Err<T>(:final failure) => onFailure(failure),
      };

  Result<R> map<R>(R Function(T value) f) => switch (this) {
        Ok<T>(:final value) => Ok(f(value)),
        Err<T>(:final failure) => Err(failure),
      };

  bool get isOk => this is Ok<T>;
  T? get valueOrNull => switch (this) { Ok<T>(:final value) => value, Err<T>() => null };
  Failure? get failureOrNull => switch (this) { Ok<T>() => null, Err<T>(:final failure) => failure };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
